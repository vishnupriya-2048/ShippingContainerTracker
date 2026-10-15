import { Controller } from "@hotwired/stimulus"
import { createMap, dotPin, fitToPoints, infoContent } from "maps/google_maps"

// Shipment detail map: the GPS trail as a polyline with direction arrows, plus
// source, destination and current-location markers. All data arrives as values.
export default class extends Controller {
  static targets = ["canvas", "message", "loading"]
  static values = {
    arrived: Boolean,   // delivered: destination pin turns into a "Delivered" pin
    path: Array,        // [{ lat, lng }, ...] oldest -> newest
    current: Object,    // { lat, lng, color, status, address, recordedAt } or {}
    source: Object,     // { lat, lng, address }
    destination: Object,
    statuses: Array,    // status-change markers: [{ id, lat, lng, status, color, glyph, address, notes, changedAt }]
    points: Array      // every GPS point, in table order: [{ lat, lng, recordedAt, address }]
  }

  async connect() {
    const api = await createMap(this.canvasTarget, { onError: this.showMessage })
    if (!api || !this.element.isConnected) return

    this.map = api.map
    this.api = api
    this.infoWindow = new api.InfoWindow({ headerDisabled: true })
    this.overlays = []
    this.statusMarkers = new Map() // status history id -> { marker, data }

    this.drawTrail()
    this.addMarker(this.sourceValue, dotPin({ color: "#16a34a", label: "Source", size: "size-7", extra: "" }), "A", "Source")
    if (this.arrivedValue) {
      // Delivered: the trail ends here, so one green "Delivered" pin replaces B and the live dot.
      this.addMarker(this.destinationValue, dotPin({ color: "#059669", label: "Delivered", size: "size-8", extra: "ring-4 ring-emerald-500/30" }), "✓", "Delivered")
    } else {
      this.addMarker(this.destinationValue, dotPin({ color: "#0f172a", label: "Destination", size: "size-7", extra: "" }), "B", "Destination")
      if (this.hasCurrent) this.addCurrentMarker()
    }

    this.addStatusMarkers()
    if (this.hasLoadingTarget) this.loadingTarget.hidden = true

    fitToPoints(this.map, [this.sourceValue, this.destinationValue, ...this.pathValue], { padding: 56, maxZoom: 14 })
  }

  disconnect() {
    this.overlays?.forEach((overlay) => (overlay.map = null))
    this.infoWindow?.close()
  }

  get hasCurrent() {
    return this.currentValue.lat !== undefined
  }

  drawTrail() {
    if (this.pathValue.length < 2) return
    const line = new google.maps.Polyline({
      map: this.map,
      path: this.pathValue,
      strokeColor: "#6366f1",
      strokeOpacity: 0.9,
      strokeWeight: 4,
      icons: [{
        icon: {
          path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW,
          scale: 3,
          fillColor: "#ffffff",
          fillOpacity: 1,
          strokeColor: "#4338ca",
          strokeWeight: 1.5
        },
        offset: "50px",
        repeat: "90px"
      }]
    })
    this.overlays.push({ set map(value) { line.setMap(value) } })
  }

  addMarker(point, content, glyph, title) {
    content.textContent = glyph
    const marker = new this.api.AdvancedMarkerElement({
      map: this.map,
      position: { lat: point.lat, lng: point.lng },
      content,
      title
    })
    marker.addListener("click", () => this.showInfo(marker, title, point.address))
    this.overlays.push(marker)
  }

  addStatusMarkers() {
    this.statusesValue.forEach((data) => {
      const pin = dotPin({ color: data.color, label: data.status, size: "size-6", extra: "ring-2 ring-white/60" })
      pin.textContent = data.glyph
      const marker = new this.api.AdvancedMarkerElement({
        map: this.map,
        position: { lat: data.lat, lng: data.lng },
        content: pin,
        title: data.status,
        zIndex: 5
      })
      marker.addListener("click", () => this.openStatus(data.id))
      this.overlays.push(marker)
      this.statusMarkers.set(data.id, { marker, data })
    })
  }

  // Action: click on a Status History row.
  focusStatus(event) {
    this.markPressed(event.currentTarget)
    this.openStatus(event.params.id)
  }

  openStatus(id) {
    const entry = this.statusMarkers?.get(id)
    if (!entry) return
    const { data, marker } = entry
    this.panTo(data)
    this.showInfo(marker, data.status, data.address, [new Date(data.changedAt).toLocaleString(), data.notes].filter(Boolean).join(" · "))
  }

  // Action: click / Enter on a Location Trail row.
  focusPoint(event) {
    const row = event.currentTarget
    row.closest("tbody").querySelectorAll("[aria-selected=true]").forEach((r) => r.setAttribute("aria-selected", "false"))
    row.setAttribute("aria-selected", "true")

    const point = this.pointsValue[event.params.index]
    if (!point || !this.map) return
    if (!this.pointMarker) {
      const pin = dotPin({ color: "#4338ca", label: "Selected point", size: "size-5", extra: "ring-8 ring-indigo-500/30" })
      this.pointMarker = new this.api.AdvancedMarkerElement({ map: this.map, content: pin, title: "Selected point", zIndex: 20 })
      this.overlays.push(this.pointMarker)
    }
    this.pointMarker.position = { lat: point.lat, lng: point.lng }
    this.panTo(point)
    this.infoWindow.close()
  }

  panTo(point) {
    this.map.panTo({ lat: point.lat, lng: point.lng })
    if (this.map.getZoom() < 12) this.map.setZoom(12)
  }

  markPressed(button) {
    button.closest("ol").querySelectorAll("[aria-pressed=true]").forEach((b) => b.setAttribute("aria-pressed", "false"))
    button.setAttribute("aria-pressed", "true")
  }

  addCurrentMarker() {
    const { color, status, address, recordedAt } = this.currentValue
    const pin = dotPin({ color, label: "Current location", size: "size-6", extra: "relative" })
    const pulse = document.createElement("span")
    pulse.className = "absolute inset-0 -z-10 animate-ping rounded-full opacity-60"
    pulse.style.backgroundColor = color
    pin.append(pulse)

    const marker = new this.api.AdvancedMarkerElement({
      map: this.map,
      position: { lat: this.currentValue.lat, lng: this.currentValue.lng },
      content: pin,
      title: "Current location",
      zIndex: 10
    })
    marker.addListener("click", () =>
      this.showInfo(marker, `Current location · ${status}`, address, new Date(recordedAt).toLocaleString())
    )
    this.overlays.push(marker)
  }

  showInfo(marker, title, ...lines) {
    this.infoWindow.setContent(infoContent(title, ...lines))
    this.infoWindow.open({ map: this.map, anchor: marker })
  }

  showMessage = () => {
    if (this.hasLoadingTarget) this.loadingTarget.hidden = true
    if (this.hasMessageTarget) this.messageTarget.hidden = false
  }
}

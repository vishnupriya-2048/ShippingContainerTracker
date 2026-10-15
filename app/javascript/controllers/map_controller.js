import { Controller } from "@hotwired/stimulus"
import { createMap, dotPin, fitToPoints, formatTime, infoContent } from "maps/google_maps"

const SELECTED_ZOOM = 9

// Dashboard map: one marker per shipment at its latest location.
// Clicking a list row (or a marker) highlights the pair and centers the map on it.
export default class extends Controller {
  static targets = ["canvas", "row", "message"]
  static values = {
    markers: Array,
    selectedId: Number
  }

  async connect() {
    this.entries = new Map() // shipment id -> { data, marker, pin }

    const api = await createMap(this.canvasTarget, { onError: this.showMessage })
    if (!api || !this.element.isConnected) return // failed, or navigated away while loading

    this.map = api.map
    this.infoWindow = new api.InfoWindow({ headerDisabled: true })

    this.markersValue.forEach((data) => {
      const pin = this.buildPin(data)
      const marker = new api.AdvancedMarkerElement({
        map: this.map,
        position: { lat: data.lat, lng: data.lng },
        content: pin,
        title: data.identifier
      })
      marker.addListener("click", () => this.focus(data.id, { scrollRow: true }))
      this.entries.set(data.id, { data, marker, pin })
    })

    fitToPoints(this.map, this.markersValue)
    this.selectedIdValueChanged(this.selectedIdValue)
  }

  disconnect() {
    this.entries?.forEach(({ marker }) => (marker.map = null))
    this.infoWindow?.close()
  }

  // Action: click / Enter on a list row.
  select(event) {
    this.focus(event.params.id)
  }

  // Action: lets the identifier link navigate without also selecting the row.
  ignore(event) {
    event.stopPropagation()
  }

  focus(id, { scrollRow = false } = {}) {
    this.selectedIdValue = id
    const entry = this.entries?.get(id)
    if (!entry) return // shipment has no location yet

    this.map.panTo(entry.marker.position)
    if (this.map.getZoom() < SELECTED_ZOOM) this.map.setZoom(SELECTED_ZOOM)

    const { identifier, status, address, recordedAt } = entry.data
    this.infoWindow.setContent(
      infoContent(identifier, status, [address, formatTime(recordedAt)].filter(Boolean).join(" · "))
    )
    this.infoWindow.open({ map: this.map, anchor: entry.marker })

    if (scrollRow) {
      this.rowTargets.find((row) => Number(row.dataset.mapIdParam) === id)
        ?.scrollIntoView({ block: "nearest", behavior: "smooth" })
    }
  }

  // Stimulus calls this whenever selectedIdValue changes, so the highlight
  // always follows state no matter what triggered the selection.
  selectedIdValueChanged(id) {
    this.rowTargets.forEach((row) => {
      row.setAttribute("aria-selected", Number(row.dataset.mapIdParam) === id)
    })
    this.entries?.forEach(({ pin, data }) => {
      pin.setAttribute("aria-selected", data.id === id)
      pin.style.zIndex = data.id === id ? 1 : 0
    })
  }

  showMessage = () => {
    if (this.hasMessageTarget) this.messageTarget.hidden = false
  }

  buildPin({ color, identifier }) {
    return dotPin({
      color,
      label: identifier,
      extra: "ring-0 aria-selected:scale-150 aria-selected:ring-8 aria-selected:ring-indigo-500/30"
    })
  }
}

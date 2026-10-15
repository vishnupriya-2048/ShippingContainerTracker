import { Controller } from "@hotwired/stimulus"

// Dashboard map: one marker per shipment at its latest location.
// Clicking a list row (or a marker) highlights the pair and centers the map on it.
export default class extends Controller {
  static targets = ["canvas", "row", "message"]
  static values = {
    markers: Array,
    selectedId: Number,
    zoom: { type: Number, default: 9 }
  }

  async connect() {
    this.entries = new Map() // shipment id -> { data, marker, pin }

    if (!window.googleMapsLoaded) return this.showMessage()
    window.addEventListener("gmaps:auth-failure", this.showMessage)

    if (window.googleMapsAuthFailed) this.showMessage()
    await window.googleMapsLoaded
    if (!this.element.isConnected) return // navigated away while the API loaded

    const { Map: GoogleMap, InfoWindow } = await google.maps.importLibrary("maps")
    const { AdvancedMarkerElement } = await google.maps.importLibrary("marker")

    this.map = new GoogleMap(this.canvasTarget, {
      center: { lat: 20, lng: 0 },
      zoom: 2,
      mapId: "DEMO_MAP_ID", // required by AdvancedMarkerElement
      disableDefaultUI: true,
      zoomControl: true,
      fullscreenControl: true,
      clickableIcons: false
    })
    this.infoWindow = new InfoWindow({ headerDisabled: true })

    this.markersValue.forEach((data) => {
      const pin = this.buildPin(data)
      const marker = new AdvancedMarkerElement({
        map: this.map,
        position: { lat: data.lat, lng: data.lng },
        content: pin,
        title: data.identifier
      })
      marker.addListener("click", () => this.focus(data.id, { scrollRow: true }))
      this.entries.set(data.id, { data, marker, pin })
    })

    this.fitAll()
  }

  disconnect() {
    window.removeEventListener("gmaps:auth-failure", this.showMessage)
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
    if (this.map.getZoom() < this.zoomValue) this.map.setZoom(this.zoomValue)

    this.infoWindow.setContent(this.buildInfo(entry.data))
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

  fitAll() {
    if (this.entries.size === 0) return
    const bounds = new google.maps.LatLngBounds()
    this.entries.forEach(({ marker }) => bounds.extend(marker.position))
    this.map.fitBounds(bounds, 64)
    // A single marker would otherwise zoom to street level.
    google.maps.event.addListenerOnce(this.map, "idle", () => {
      if (this.map.getZoom() > 12) this.map.setZoom(12)
    })
  }

  showMessage = () => {
    if (this.hasMessageTarget) this.messageTarget.hidden = false
  }

  buildPin({ color, identifier }) {
    const pin = document.createElement("div")
    pin.setAttribute("aria-label", identifier)
    pin.className =
      "size-5 cursor-pointer rounded-full border-[3px] border-white shadow-lg ring-0 transition " +
      "hover:scale-125 aria-selected:scale-150 aria-selected:ring-8 aria-selected:ring-indigo-500/30"
    pin.style.backgroundColor = color
    return pin
  }

  buildInfo({ identifier, status, address, recordedAt }) {
    const box = document.createElement("div")
    box.className = "min-w-40 p-1 font-sans text-sm"

    const title = document.createElement("p")
    title.className = "font-semibold text-slate-900"
    title.textContent = identifier

    const meta = document.createElement("p")
    meta.className = "text-slate-600"
    meta.textContent = status

    const when = document.createElement("p")
    when.className = "text-xs text-slate-500"
    when.textContent = [address, new Date(recordedAt).toLocaleString()].filter(Boolean).join(" · ")

    box.append(title, meta, when)
    return box
  }
}

// Shared Google Maps plumbing for the Stimulus map controllers.

// Resolves to { map, InfoWindow, AdvancedMarkerElement } once the Maps API is
// ready, or null if it can't load (no key, rejected key). `onError` runs in
// those cases so the caller can show its fallback message.
export async function createMap(canvas, { onError, ...options } = {}) {
  if (!window.googleMapsLoaded) return fail(onError)

  window.addEventListener("gmaps:auth-failure", () => onError?.(), { once: true })
  if (window.googleMapsAuthFailed) onError?.()
  await window.googleMapsLoaded

  const { Map, InfoWindow } = await google.maps.importLibrary("maps")
  const { AdvancedMarkerElement } = await google.maps.importLibrary("marker")

  const map = new Map(canvas, {
    center: { lat: 20, lng: 0 },
    zoom: 2,
    mapId: "DEMO_MAP_ID", // required by AdvancedMarkerElement
    disableDefaultUI: true,
    zoomControl: true,
    fullscreenControl: true,
    clickableIcons: false,
    ...options
  })

  return { map, InfoWindow, AdvancedMarkerElement }
}

function fail(onError) {
  onError?.()
  return null
}

// Colors for the markers that aren't status-driven (statuses get theirs from the server).
export const MARKER_COLORS = {
  source: "#16a34a",
  destination: "#0f172a",
  delivered: "#10b981",
  selectedPoint: "#4338ca"
}

// Same instant, same zone as the server-rendered times.
export function formatTime(iso) {
  const text = new Date(iso).toLocaleString("en-US", {
    month: "long", day: "2-digit", year: "numeric",
    hour: "2-digit", minute: "2-digit", hourCycle: "h23", timeZone: "UTC"
  })
  return `${text} UTC`
}

// A round, colored marker. Style it further with aria-selected:* Tailwind variants.
export function dotPin({ color, label, glyph = "", size = "size-5", extra = "" }) {
  const pin = document.createElement("div")
  pin.setAttribute("aria-label", label)
  pin.textContent = glyph
  pin.className =
    `${size} grid cursor-pointer place-items-center rounded-full border-[3px] border-white text-[10px] ` +
    `font-bold text-white shadow-lg transition hover:scale-125 ${extra}`
  pin.style.backgroundColor = color
  return pin
}

// Fit the map to the given { lat, lng } points; a lone point is capped at maxZoom.
export function fitToPoints(map, points, { padding = 64, maxZoom = 12 } = {}) {
  if (points.length === 0) return
  const bounds = new google.maps.LatLngBounds()
  points.forEach((point) => bounds.extend(point))
  map.fitBounds(bounds, padding)
  google.maps.event.addListenerOnce(map, "idle", () => {
    if (map.getZoom() > maxZoom) map.setZoom(maxZoom)
  })
}

// Small DOM info-window body (textContent only, so nothing is interpreted as HTML).
export function infoContent(title, ...lines) {
  const box = document.createElement("div")
  box.className = "min-w-40 p-1 font-sans text-sm"
  const heading = document.createElement("p")
  heading.className = "font-semibold text-slate-900"
  heading.textContent = title
  box.append(heading)
  lines.filter(Boolean).forEach((text, i) => {
    const line = document.createElement("p")
    line.className = i === 0 ? "text-slate-600" : "text-xs text-slate-500"
    line.textContent = text
    box.append(line)
  })
  return box
}

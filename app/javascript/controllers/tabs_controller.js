import { Controller } from "@hotwired/stimulus"

// Minimal accessible tabs: shows one panel, hides the rest. Only toggles the
// `hidden` attribute, so nothing else on the page (e.g. the map) is re-rendered.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { index: { type: Number, default: 0 } }

  // Action: click on a tab button.
  show(event) {
    this.indexValue = event.params.index
  }

  // Action: arrow keys / Home / End move between tabs.
  key(event) {
    const last = this.tabTargets.length - 1
    const moves = { ArrowRight: this.indexValue + 1, ArrowLeft: this.indexValue - 1, Home: 0, End: last }
    if (!(event.key in moves)) return
    event.preventDefault()
    this.indexValue = Math.min(Math.max(moves[event.key], 0), last)
    this.tabTargets[this.indexValue].focus()
  }

  indexValueChanged(index) {
    this.tabTargets.forEach((tab, i) => {
      tab.setAttribute("aria-selected", i === index)
      tab.tabIndex = i === index ? 0 : -1
    })
    this.panelTargets.forEach((panel, i) => (panel.hidden = i !== index))
  }
}

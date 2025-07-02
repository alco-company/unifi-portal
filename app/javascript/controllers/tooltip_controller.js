import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tooltip"
export default class extends Controller {
  static targets = ["tooltip"]

  connect() {
  }

  toggle() {
    const el = this.tooltipTarget
    const isVisible = !el.classList.contains("opacity-0")
  
    if (isVisible) {
      el.classList.add("opacity-0", "pointer-events-none")
    } else {
      el.classList.remove("opacity-0", "pointer-events-none")
    }
  }

  hide() {
    this.tooltipTarget.classList.add("hidden")
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tooltip"
export default class extends Controller {
  connect() {
  }
  static targets = ["tooltip"]

  toggle() {
    this.tooltipTarget.classList.toggle("hidden")
  }

  hide() {
    this.tooltipTarget.classList.add("hidden")
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 300 } // ms
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  search(event) {
    clearTimeout(this.timeout)

    const query = event.target.value.trim()

    this.timeout = setTimeout(() => {
      if (query) {
        const url = new URL(window.location.href)
        url.searchParams.set("query", query)
        window.location.href = url.toString()
      }
    }, this.delayValue)
  }
}

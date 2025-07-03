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

  keydown(event) {
    // If the user presses Enter, we want to submit the form
    if (event.key === "Enter") {
      event.preventDefault()
      this.search(event)
    }
  }

  search(event) {
    clearTimeout(this.timeout)

    let query = event.target.value.trim()

    this.timeout = setTimeout(() => {
      if (query === "") {
        query = "*"
      }
      const url = new URL(window.location.href)
      url.searchParams.set("query", query)
      window.location.href = url.toString()
    }, this.delayValue)
  }
}

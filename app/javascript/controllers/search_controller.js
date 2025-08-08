import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = [
    "input"
  ]

  static values = {
    delay: { type: Number, default: 300 } // ms
  }

  connect() {
    this.timeout = null
   if (this.hasInputTarget) {
     const input = this.inputTarget;
     const length = input.value.length;

     // Set focus and move caret to the end
     input.focus();
     input.setSelectionRange(length, length);
   }    
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

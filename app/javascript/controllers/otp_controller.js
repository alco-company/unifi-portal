import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input"];

  connect() {
    this.inputTarget.focus();
  }

  submitIfComplete(event) {
    const value = this.inputTarget.value.trim();
    if (value.length === 6 && /^\d{6}$/.test(value)) {
      this.element.requestSubmit();
    }
  }

  handlePaste(event) {
    const pasted = event.clipboardData.getData("text").trim();
    if (/^\d{6}$/.test(pasted)) {
      event.preventDefault();
      this.inputTarget.value = pasted;
      this.submitIfComplete();
    }
  }

  submit(event){
    event.target.classList.add("opacity-50", "cursor-not-allowed");
  }
}

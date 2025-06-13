import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { seconds: Number };
  static targets = ["button", "countdown"];

  connect() {
    this.remaining = this.secondsValue;
    this.updateUI();
    this.tick();
  }

  tick() {
    if (this.remaining > 0) {
      this.remaining--;
      this.updateUI();
      setTimeout(() => this.tick(), 1000);
    } else {
      this.showButton();
    }
  }

  updateUI() {
    if (this.countdownTarget) {
      this.countdownTarget.textContent = `Du kan få tilsendt en ny kode igen om ${this.remaining}s`;
    }
    this.hideButton();
  }

  showButton() {
    this.buttonTarget.classList.remove("hidden");
    this.countdownTarget.classList.add("hidden");
  }

  hideButton() {
    this.buttonTarget.classList.add("hidden");
    this.countdownTarget.classList.remove("hidden");
  }
}

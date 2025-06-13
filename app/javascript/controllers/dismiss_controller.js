import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { delay: Number };

  connect() {
    setTimeout(() => this.element.remove(), this.delayValue || 3000);
  }
}

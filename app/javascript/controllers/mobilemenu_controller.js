import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobilemenu"
export default class extends Controller {
  connect() {
  }
  toggle(event) {
    event.preventDefault();
    const mobileMenu = document.getElementById("mobile-menu");
    if (mobileMenu) {
      mobileMenu.classList.toggle("hidden");
      mobileMenu.classList.toggle("block");
    }
  }
}

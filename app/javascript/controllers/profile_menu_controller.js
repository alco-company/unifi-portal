import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="profile-menu"
export default class extends Controller {
  connect() {
  }
  toggle(event) {
    event.preventDefault();
    const menu = document.getElementById("profile-menu");
    if (menu) {
      menu.classList.toggle("hidden");
      menu.classList.toggle("block");
    }
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="controller-type"
// This controller manages the visibility of form fields based on the selected controller type (basic or API).
// It toggles the visibility of basic and API fields when the controller type is changed.
export default class extends Controller {
  static targets = ["basicFields", "apiFields"]

  connect() {
    this.toggle()
  }

  change(event) {
    this.toggle(event.target.value)
  }

  toggle(type="login") {
    if (type === "api_key") {
      document.getElementById("site_controller_type_api_key").checked = true // Clear API key field
      this.basicFieldsTarget.classList.add("hidden")
      this.apiFieldsTarget.classList.remove("hidden")
    } else if (type === "login") {
      document.getElementById("site_controller_type_login").checked = true; // Clear login field
      this.basicFieldsTarget.classList.remove("hidden");
      this.apiFieldsTarget.classList.add("hidden");
    }
  }
}
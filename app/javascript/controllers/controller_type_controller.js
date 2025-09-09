import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="controller-type"
// This controller manages the visibility of form fields based on the selected controller type (basic or API).
// It toggles the visibility of basic and API fields when the controller type is changed.
export default class extends Controller {
  static targets = ["basicFields", "apiFields"]
  static values = { type: String }

  connect() {
    this.toggle(this.typeValue);
  }

  change(event) {
    this.toggle(event.target.value)
  }

  toggle(type="login") {
    switch (type) {
      case "login":
        document.getElementById("site_controller_type_login").checked = true; // Clear login field
        this.basicFieldsTarget.classList.remove("hidden");
        this.apiFieldsTarget.classList.add("hidden");
        break;
      case "api_key":
        document.getElementById("site_controller_type_api_key").checked = true; // Clear API key field
        this.basicFieldsTarget.classList.add("hidden");
        this.apiFieldsTarget.classList.remove("hidden");
        break;
      case "radius":
        document.getElementById("site_controller_type_radius").checked = true; // Clear RADIUS field
        this.basicFieldsTarget.classList.add("hidden");
        this.apiFieldsTarget.classList.add("hidden");
        break;
      default:
        this.showBasicFields();
        break;
    }
  }
}

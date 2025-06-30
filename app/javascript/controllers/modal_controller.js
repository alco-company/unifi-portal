// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog"];

  show(event) {
    event.preventDefault();
    console.log("Modal show triggered");
    this.dialogTarget.showModal();
    this.dialogTarget.dataset.actionUrl = event.target.dataset.actionUrl;
  }

  confirm(event) {
    const form = document.getElementById("delete-form");
    form.action = this.dialogTarget.dataset.actionUrl;
    form.submit();
  }

  cancel() {
    this.dialogTarget.close();
  }
}

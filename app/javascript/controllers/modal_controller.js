// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "dialog",
    "upload"
  ];

  show(event) {
    event.preventDefault();
    console.log("Modal show triggered");
    this.dialogTarget.showModal();
    this.dialogTarget.dataset.actionUrl = event.target.dataset.actionUrl;
  }

  showUpload(event) {
    event.preventDefault();
    this.uploadTarget.showModal();
    this.uploadTarget.dataset.actionUrl = event.target.dataset.actionUrl;
  }

  confirm(event) {
    const form = document.getElementById("delete-form");
    form.action = this.dialogTarget.dataset.actionUrl;
    form.submit();
  }

  cancel() {
    this.dialogTarget.close();
  }

  cancelUpload() {
    this.uploadTarget.close();
  }
}

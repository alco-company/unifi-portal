import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="device"
export default class extends Controller {
  connect() {
  }

  show(event) {
    event.preventDefault();
    const clientId = event.currentTarget.dataset.clientId;
    const deviceId = event.currentTarget.dataset.deviceId;
    const clientName = event.currentTarget.dataset.clientName;

    window.location.href = `/admin/clients/${clientId}/devices/${deviceId}`;
  }
}

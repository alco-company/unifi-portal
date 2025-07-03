import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="user"
export default class extends Controller {
  connect() {
  }

  show(event) {
    event.preventDefault();
    const tenantId = event.currentTarget.dataset.tenantId;
    const userId = event.currentTarget.dataset.userId;
    const userName = event.currentTarget.dataset.userName;

    window.location.href = `/admin/tenants/${tenantId}/users/${userId}`;
    // Update the modal content
    // const modalTitle = document.querySelector('#tenantModal .modal-title');
    // const modalBody = document.querySelector('#tenantModal .modal-body');

    // modalTitle.textContent = `Tenant: ${tenantName}`;
    // modalBody.innerHTML = `<p>Details for tenant ID: ${tenantId}</p>`;

    // // Show the modal
    // const tenantModal = new bootstrap.Modal(document.getElementById('tenantModal'));
    // tenantModal.show();
  }
}

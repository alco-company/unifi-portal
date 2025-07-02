import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="site"
export default class extends Controller {
  connect() {
  }

  show(event) {
    event.preventDefault();
    const tenantId = event.currentTarget.dataset.tenantId;
    const siteId = event.currentTarget.dataset.siteId;
    const tenantName = event.currentTarget.dataset.tenantName;

    window.location.href = `/admin/tenants/${tenantId}/sites/${siteId}`;
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

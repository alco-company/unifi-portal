import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="active"
export default class extends Controller {
  connect() {
  }

  toggle(event) {
    event.stopPropagation()
    event.preventDefault()
    const checkbox = event.currentTarget
    const checked = checkbox.checked
    const resourceId = checkbox.dataset.resourceId
    const resourceClass = checkbox.dataset.resourceClass

    console.log( `Toggling active status for ${resourceClass} with ID ${resourceId} to ${checked}`)
    fetch(`/toggle_active`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ active: checked, resource: resourceClass, id: resourceId })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log(
          `Tenant ${resourceId} active status updated to ${!checked}`
        );
        checkbox.checked = checked
      } else {
        console.error(`Failed to update ${resource} - error: ${data.error}`)
      }
    })
    .catch(error => console.error('Error:', error))
  } 
}

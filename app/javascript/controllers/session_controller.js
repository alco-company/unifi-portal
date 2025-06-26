import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="session"
export default class extends Controller {
  connect() {
  }

  checkPnr(event) {
    event.preventDefault();
    const pnrInput = event.target;
    const pnr = pnrInput.value.trim();

    if (pnr === '') {
      pnrInput.classList.add('border', 'border-yellow-500');
      return;
    } else {
      fetch(`/check_pnr?pnr=${encodeURIComponent(pnr)}`)
        .then(response => response.json())
        .then(data => {
          console.log(data)
          pnrInput.classList.add("border", "border-green-500");
        })
        .catch(error => {
          console.error('Error checking PNR:', error);
          alert('An error occurred while checking the PNR.');
        });
    }
  }

  checkPhoneNumber(event) {
    event.preventDefault();
    const phoneInput = event.target;
    const phone = phoneInput.value.trim();

    if (phone === '') {
      phoneInput.classList.add('border', 'border-yellow-500');
      return;
    } else {
      fetch(`/check_phone?phone=${encodeURIComponent(phone)}`)
        .then(response => response.json())
        .then(data => {
          console.log(data)
          phoneInput.classList.add("border", "border-green-500");
        })
        .catch(error => {
          console.error('Error checking phone number:', error);
          alert('An error occurred while checking the phone number.');
        });
    }
  }
}

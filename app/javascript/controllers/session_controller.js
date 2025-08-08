import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="session"
export default class extends Controller {
  static targets = [
    "phonediv"
  ]

  connect() {
  }

  // checkPnr(event) {
  //   event.preventDefault();
  //   const pnrInput = event.target;
  //   const pnr = pnrInput.value.trim();

  //   if (pnr === '') {
  //     pnrInput.parentElement.classList.add('border', 'border-yellow-500');
  //     return;
  //   } else {
  //     fetch(`/check_pnr?pnr=${encodeURIComponent(pnr)}`)
  //       .then(response => response.json())
  //       .then(data => {
  //         console.log(data)
  //         pnrInput.parentElement.classList.add("border", "border-green-500");
  //         document.querySelector("#name").disabled = true;
  //         document.querySelector("#email").disabled = true;
  //       })
  //       .catch(error => {
  //         console.error('Error checking PNR:', error);
  //         alert('An error occurred while checking the PNR.');
  //       });
  //   }
  // }

  checkPhoneNumber(event) {
    event.preventDefault();
    const phoneInput = event.target;
    const phone = phoneInput.value.trim();

    if (phone === '') {
      phoneInput.parentElement.classList.add('border', 'border-yellow-500');
      return;
    } else {
      fetch(`/check_phone?phone=${encodeURIComponent(phone)}`)
        .then(response => response.json())
        .then(data => {
          if (!data.exists) {
            this.phonedivTarget.classList.remove("border-green-500");
            this.phonedivTarget.classList.add("border", "border-yellow-500");
          } else {
            this.phonedivTarget.classList.remove("border-yellow-500");
            this.phonedivTarget.classList.add("border-green-500");
            document.querySelector("#name").disabled = true;
            document.querySelector("#email").disabled = true;
            document.getElementById("submit-otp").click();
          }
        })
        .catch(error => {
          console.error('Error checking phone number:', error);
          alert('An error occurred while checking the phone number.');
        });
    }
  }

  // showPnrModal(event) {
  //   event.preventDefault();
  //   const modal = document.querySelector("#pnrModal");
  //   if (modal) {
  //     modal.classList.remove("hidden");
  //     modal.classList.add("flex");
  //   }
  // }
}

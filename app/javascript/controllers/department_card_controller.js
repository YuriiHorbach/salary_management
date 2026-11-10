import { Controller } from "@hotwired/stimulus"

// Highlights a department card when its checkbox is checked.
//
// The card starts with the default white background. Checking the box swaps
// the neutral classes for the configured selected classes (a green palette),
// and unchecking restores the default look. State is intentionally ephemeral:
// it is only used to visually mark cards during the current page visit.
export default class extends Controller {
  static classes = ["selected"]

  connect() {
    const checkbox = this.element.querySelector("input[type='checkbox']")
    this.apply(checkbox ? checkbox.checked : false)
  }

  toggle(event) {
    this.apply(event.target.checked)
  }

  apply(selected) {
    this.element.classList.toggle("bg-white", !selected)
    this.element.classList.toggle("border-gray-200", !selected)

    this.selectedClasses.forEach((className) => {
      this.element.classList.toggle(className, selected)
    })
  }
}

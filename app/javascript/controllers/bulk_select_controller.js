import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "toggleAll", "submit", "count"]

  connect() {
    this.update()
  }

  toggleAll() {
    const checked = this.toggleAllTarget.checked

    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = checked
    })

    this.update()
  }

  update() {
    const selected = this.checkboxTargets.filter((checkbox) => checkbox.checked).length
    const total = this.checkboxTargets.length

    if (this.hasCountTarget) {
      this.countTarget.textContent = `${selected} selected`
    }

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = selected === 0
      this.submitTarget.value = selected > 0 ? `Add selected (${selected})` : "Add Employees"
    }

    if (this.hasToggleAllTarget) {
      this.toggleAllTarget.checked = selected > 0 && selected === total
      this.toggleAllTarget.indeterminate = selected > 0 && selected < total
    }
  }
}

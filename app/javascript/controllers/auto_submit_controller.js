import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._onFormSubmit = this._onFormSubmit.bind(this)

    const form = this.element.form || this.element.closest("form")
    if (form) {
      form.dataset.submitting = "false"
      form.addEventListener("submit", this._onFormSubmit)
    }
  }

  disconnect() {
    const form = this.element.form || this.element.closest("form")
    if (form) {
      form.removeEventListener("submit", this._onFormSubmit)
      delete form.dataset.submitting
    }
  }

  _onFormSubmit(event) {
    const form = event.currentTarget
    if (form) {
      form.dataset.submitting = "true"
    }
  }

  submit(event) {
    const form = this.element.form || this.element.closest("form")
    if (!form) {
      return
    }

    // If the form is already being submitted (e.g. native Enter key),
    // do not trigger another submission via Stimulus.
    if (form.dataset.submitting === "true") {
      return
    }

    form.dataset.submitting = "true"

    try {
      if (typeof form.requestSubmit === "function") {
        form.requestSubmit()
      } else {
        form.submit()
      }
    } catch (error) {
      form.dataset.submitting = "false"
    }
  }
}

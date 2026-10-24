import { Controller } from "@hotwired/stimulus"

// Submits the enclosing form when focus leaves the form as a whole.
//
// Used by the inline salary form: moving from the amount input to the position
// select or the Save button must not submit early, but leaving the salary cell
// should save through Turbo. The controller relies on requestSubmit() so Turbo
// intercepts the submission and the browser runs constraint validation.
export default class extends Controller {
  connect() {
    this._markSubmitting = this._markSubmitting.bind(this)
    this._resetSubmitting = this._resetSubmitting.bind(this)

    this.element.addEventListener("submit", this._markSubmitting)
    this.element.addEventListener("turbo:submit-end", this._resetSubmitting)
  }

  disconnect() {
    this.element.removeEventListener("submit", this._markSubmitting)
    this.element.removeEventListener("turbo:submit-end", this._resetSubmitting)
  }

  submit(event) {
    // Focus stayed inside the form, for example when moving from the amount
    // input to the position select or clicking the Save button.
    if (event.relatedTarget && this.element.contains(event.relatedTarget)) return

    // A request is already in flight; avoid a duplicate Turbo submission.
    if (this.element.dataset.submitting === "true") return

    // Do not auto-submit an empty or invalid cell. The explicit Save button
    // remains available for showing browser validation messages.
    if (!this.element.checkValidity()) return

    const submitter = this.element.querySelector(
      'input[type="submit"], button[type="submit"]'
    )
    this.element.requestSubmit(submitter || undefined)
  }

  _markSubmitting() {
    this.element.dataset.submitting = "true"
  }

  _resetSubmitting(event) {
    // Successful submissions replace the form. Reset after failures so a
    // network error does not leave the form permanently blocked.
    if (!event.detail.success) delete this.element.dataset.submitting
  }
}

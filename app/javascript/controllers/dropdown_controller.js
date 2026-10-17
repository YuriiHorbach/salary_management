import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("toggle", this._onToggle.bind(this))
    document.addEventListener("click", this._onClickOutside.bind(this))
    document.addEventListener("keydown", this._onKeydown.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("toggle", this._onToggle.bind(this))
    document.removeEventListener("click", this._onClickOutside.bind(this))
    document.removeEventListener("keydown", this._onKeydown.bind(this))
  }

  _onToggle() {
    if (this.element.open) {
      document.querySelectorAll("details[data-controller='dropdown']").forEach((detail) => {
        if (detail !== this.element && detail.open) {
          detail.open = false
        }
      })
    }
  }

  _onClickOutside(event) {
    if (!this.element.open) return
    if (!this.element.contains(event.target)) {
      this.element.open = false
    }
  }

  _onKeydown(event) {
    if (event.key === "Escape" && this.element.open) {
      this.element.open = false
    }
  }
}

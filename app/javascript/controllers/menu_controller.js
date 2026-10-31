import { Controller } from "@hotwired/stimulus"

// Toggles the mobile navigation menu (below the `lg` breakpoint).
//
// The menu element carries `hidden` by default and is shown inline on
// desktop via `lg:flex`; this controller only manages the mobile
// open/closed state plus the toggle button's `aria-expanded` flag.
export default class extends Controller {
  static targets = ["menu", "toggle"]

  connect() {
    this._onClickOutside = this._onClickOutside.bind(this)
    this._onKeydown = this._onKeydown.bind(this)
    document.addEventListener("click", this._onClickOutside)
    document.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this._onClickOutside)
    document.removeEventListener("keydown", this._onKeydown)
  }

  toggle(event) {
    event.stopPropagation()
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.menuTarget.classList.add("flex")
    this.toggleTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.menuTarget.classList.remove("flex")
    this.toggleTarget.setAttribute("aria-expanded", "false")
  }

  get isOpen() {
    return !this.menuTarget.classList.contains("hidden")
  }

  _onClickOutside(event) {
    if (!this.isOpen) return
    if (this.element.contains(event.target)) return
    this.close()
  }

  _onKeydown(event) {
    if (event.key === "Escape" && this.isOpen) this.close()
  }
}

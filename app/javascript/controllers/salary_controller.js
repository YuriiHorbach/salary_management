import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.querySelectorAll("input").forEach(input => {
      input.addEventListener("input", this.updateSalary.bind(this));
      input.addEventListener("blur", this.updateSalary.bind(this));
      input.addEventListener("change", this.updateSalary.bind(this));
    });
  }

  disconnect() {
    this.element.querySelectorAll("input").forEach(input => {
      input.removeEventListener("input", this.updateSalary.bind(this));
      input.removeEventListener("blur", this.updateSalary.bind(this));
      input.removeEventListener("change", this.updateSalary.bind(this));
    });
  }

  updateSalary(event) {
    const form = this.element.closest("form");

    if (form) {
      fetch(form.action, {
        method: form.method,
        body: new FormData(form),
        headers: { "X-Requested-With": "XMLHttpRequest" }
      })
      .then(response => response.text())
      .then(html => {
        const frameId = form.dataset.turboFrame;
        if (frameId) {
          const frame = document.getElementById(frameId);
          if (frame) {
            frame.innerHTML = html;
          }
        }
      });
    }
  }
}

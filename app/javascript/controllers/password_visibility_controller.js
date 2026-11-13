import { Controller } from "@hotwired/stimulus"

// Eye button of a password field (FiftyFormBuilder#field as: :password).
// Shows or hides what was typed; the label stays « Afficher le mot de passe »
// and aria-pressed carries the state. The field goes back to hidden when the
// form is sent and before Turbo caches the page, so going back never shows a
// password in clear.
export default class extends Controller {
  connect() {
    this.input = this.element.querySelector("input")
    this.button = this.element.querySelector("button")
    this.hide = this.hide.bind(this)
    this.input.form?.addEventListener("submit", this.hide)
    document.addEventListener("turbo:before-cache", this.hide)
  }

  disconnect() {
    this.input.form?.removeEventListener("submit", this.hide)
    document.removeEventListener("turbo:before-cache", this.hide)
  }

  toggle() {
    this.show(this.input.type === "password")
  }

  hide() {
    this.show(false)
  }

  show(visible) {
    this.input.type = visible ? "text" : "password"
    this.button.setAttribute("aria-pressed", String(visible))
  }
}

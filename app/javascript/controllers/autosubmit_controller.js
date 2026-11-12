import { Controller } from "@hotwired/stimulus"

// Saves a form of switches as soon as one changes. The submit button stays
// for people without JavaScript.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}

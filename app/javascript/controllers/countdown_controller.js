import { Controller } from "@hotwired/stimulus"

// Cooldown on a "resend" button: disabled, with the remaining seconds in its
// label, until the delay is over. The server also limits sends (3 per hour per
// address): this countdown only tells the person when it is worth trying.
//
//   <div data-controller="countdown" data-countdown-seconds-value="42"
//        data-countdown-wait-label-value="Renvoyer · possible dans %s s">
//     <button data-countdown-target="button" disabled>…</button>
export default class extends Controller {
  static targets = ["button"]
  static values = { seconds: Number, waitLabel: String }

  connect() {
    this.readyLabel = this.buttonTarget.textContent.trim()
    this.remaining = this.secondsValue
    this.tick()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  tick() {
    if (this.remaining > 0) {
      this.buttonTarget.disabled = true
      this.buttonTarget.setAttribute("aria-disabled", "true")
      this.buttonTarget.textContent = this.waitLabelValue.replace("%s", this.remaining)
      this.remaining -= 1
      this.timer = setTimeout(() => this.tick(), 1000)
    } else {
      this.buttonTarget.disabled = false
      this.buttonTarget.removeAttribute("aria-disabled")
      this.buttonTarget.textContent = this.readyLabel
    }
  }
}

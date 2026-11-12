import { Controller } from "@hotwired/stimulus"

// Live shares in the split editors (C4, C8, C9, B11, B14). When an
// assignment changes, the form as it stands is posted to the preview
// endpoint, which answers with a Turbo Stream replacing the bar. The maths
// stay on the server (PlannedSplit): nothing is computed here, nothing is
// saved. The « Mettre à jour les parts » button is the fallback without
// JavaScript, hidden once this controller runs.
export default class extends Controller {
  static targets = [ "fallback" ]
  static values = { url: String, delay: { type: Number, default: 250 } }

  connect() {
    this.fallbackTargets.forEach((element) => { element.hidden = true })
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  refresh(event) {
    if (event && event.target && event.target.name === "carry_gap") return

    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.post(), this.delayValue)
  }

  async post() {
    const body = new FormData(this.element)
    body.delete("_method")
    body.delete("commit_action")
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(this.urlValue, {
      method: "POST",
      body,
      headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": token || "" },
      credentials: "same-origin"
    })
    if (response.ok) window.Turbo.renderStreamMessage(await response.text())
  }
}

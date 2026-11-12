import { Turbo } from "@hotwired/turbo-rails"
import { BridgeComponent } from "native_bridge"

// Bridge component « push-notifications » (lots 8b and 9).
//
// Two uses:
//   - in the layout, for a signed-in person in a native shell (mode "sync"):
//     asks the shell for the permission state and the phone's FCM token
//     (event "connect", no prompt) and registers the token with the server
//     when this session has not registered it yet. A permission withdrawn in
//     the phone's settings unregisters the token the shell last knew.
//   - on H1 (mode "ask"): « Activer » sends "request"; the shell shows the
//     system prompt and answers. Granted: the token is registered (when
//     signed in; otherwise the shell keeps it and the layout registers it
//     after sign-in) and the next screen opens. Refused: the screen says the
//     email stays the channel, with a way to the phone's settings.
//
// Native reply data: { permission: "granted" | "denied" | "not_determined",
//                      token, platform: "ios" | "android", previousToken }
export default class extends BridgeComponent {
  static component = "push-notifications"
  static values = { mode: String, url: String, signedIn: Boolean, deviceDigest: String, nextUrl: String }
  static targets = ["denied"]

  connect() {
    if (this.modeValue === "sync") {
      this.send("connect", {}, (message) => this.sync(message.data))
    }
  }

  request(event) {
    if (!this.enabled) return // no shell answering: the link goes on to the next screen
    event.preventDefault()
    this.send("request", {}, async (message) => {
      if (message.data.permission === "granted") {
        await this.sync(message.data)
        this.continue()
      } else {
        this.deniedTargets.forEach((element) => { element.hidden = false })
      }
    })
  }

  continue() {
    if (this.nextUrlValue) Turbo.visit(this.nextUrlValue)
  }

  async sync({ permission, token, platform, previousToken }) {
    if (!this.signedInValue) return

    if (permission === "granted" && token) {
      if (await this.digest(token) === this.deviceDigestValue) return
      if (await this.call("POST", { token, platform })) this.deviceDigestValue = await this.digest(token)
    } else if (previousToken) {
      await this.call("DELETE", { token: previousToken })
      this.deviceDigestValue = ""
    }
  }

  async digest(token) {
    try {
      const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token))
      return Array.from(new Uint8Array(bytes)).map((b) => b.toString(16).padStart(2, "0")).join("")
    } catch {
      return null
    }
  }

  async call(method, body) {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const response = await fetch(this.urlValue, {
        method,
        credentials: "same-origin",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": csrf },
        body: JSON.stringify(body)
      })
      return response.ok
    } catch {
      return false
    }
  }
}

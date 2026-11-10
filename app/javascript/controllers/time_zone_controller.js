import { Controller } from "@hotwired/stimulus"

// Fills a hidden field with the browser's IANA time zone (e.g. "Europe/Paris").
// The server ignores a value it does not know and keeps its default.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    try {
      const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
      if (zone) this.inputTarget.value = zone
    } catch (_error) {
      // keep the server default
    }
  }
}

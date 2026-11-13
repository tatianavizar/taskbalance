import { BridgeComponent } from "native_bridge"

// Bridge component « settings » (lot 9): opens this app's page in the
// phone's settings, where notifications are allowed or refused. Only rendered
// in the native shells.
export default class extends BridgeComponent {
  static component = "settings"

  open(event) {
    event.preventDefault()
    this.send("open")
  }
}

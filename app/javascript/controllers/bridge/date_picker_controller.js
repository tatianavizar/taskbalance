import { BridgeComponent } from "native_bridge"

// Bridge component « date-picker » (lot 9, D10, F6), on every
// `f.field ..., as: :date` (FiftyFormBuilder). In a native shell that
// supports it, a tap opens the native picker within the input's min/max and
// the answer fills the input (then "input" and "change" fire, as if typed).
// Anywhere else the browser's own picker opens, untouched.
//
// Native reply data: { value: "YYYY-MM-DD" } (absent when cancelled).
export default class extends BridgeComponent {
  static component = "date-picker"

  open(event) {
    if (!this.enabled) return
    event.preventDefault()

    const input = this.element
    this.send("show", { value: input.value, min: input.min, max: input.max }, (message) => {
      const value = message.data.value
      if (!value) return
      input.value = value
      input.dispatchEvent(new Event("input", { bubbles: true }))
      input.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }
}

import { Controller } from "@hotwired/stimulus"

// D6: the form that logs a task. Everything works without JavaScript (a plain
// number field, a select of tasks, a name field); this adds the ±5 minute
// buttons and prefills the loads and the duration when a task is chosen.
export default class extends Controller {
  static targets = ["chore", "custom", "mental", "execution", "minutes"]
  static values = { step: { type: Number, default: 5 } }

  connect() {
    this.toggleCustom()
  }

  more() { this.shift(this.stepValue) }
  less() { this.shift(-this.stepValue) }

  shift(delta) {
    const current = parseInt(this.minutesTarget.value, 10) || 0
    this.minutesTarget.value = Math.max(1, current + delta)
    this.minutesTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  choose() {
    const option = this.choreTarget.selectedOptions[0]
    if (option && option.value) {
      this.mentalTarget.checked = option.dataset.mental === "true"
      this.executionTarget.checked = option.dataset.execution === "true"
      if (option.dataset.minutes) this.minutesTarget.value = option.dataset.minutes
    }
    this.toggleCustom()
  }

  // The name and category are only asked when no task of the household is chosen.
  toggleCustom() {
    if (!this.hasCustomTarget) return
    this.customTarget.hidden = this.choreTarget.value !== ""
  }
}

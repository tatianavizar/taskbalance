import { Controller } from "@hotwired/stimulus"

// Feuille d'assignation (P6, C14) : un <dialog> ouvert en modal depuis le
// bouton de la ligne. Le focus entre dans la feuille (première case), Échap la
// ferme, et le focus revient au bouton qui l'a ouverte. Les cases font partie
// du formulaire de la répartition : un changement déclenche le recalcul des
// parts comme avec les pastilles. Le bouton de la ligne et le bouton de
// validation suivent les cases cochées.
export default class extends Controller {
  static targets = [ "dialog", "opener", "label", "box", "confirm" ]
  static values = { aria: String, everyone: String, nobody: String, one: String, other: String, total: Number }

  open() {
    if (typeof this.dialogTarget.showModal !== "function") return

    this.dialogTarget.showModal()
    const first = this.boxTargets.find((box) => box.checked) || this.boxTargets[0]
    first?.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  // Un clic sur le fond (le <dialog> lui-même) ferme la feuille.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  closed() {
    this.openerTarget.focus()
  }

  update() {
    const names = this.boxTargets.filter((box) => box.checked).map((box) => box.dataset.name)
    let text
    if (names.length === 0) text = this.nobodyValue
    else if (names.length === this.totalValue) text = this.everyoneValue
    else text = names.join(", ")
    this.labelTarget.textContent = text
    this.openerTarget.setAttribute("aria-label", this.ariaValue.replace("%s", text))
    const template = names.length > 1 ? this.otherValue : this.oneValue
    this.confirmTarget.textContent = template.replace("%s", names.length)
  }
}

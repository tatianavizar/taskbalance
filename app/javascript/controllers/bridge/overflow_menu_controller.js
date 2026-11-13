import { BridgeComponent } from "native_bridge"

// Bridge component « overflow-menu » (lot 9, E6): the « ⋯ » of a row. In a
// native shell that supports it, a tap opens a native action sheet listing the
// `item` targets (links or buttons, hidden on the page); choosing one clicks
// it, so Turbo and the path configuration do the rest. In a browser, the « ⋯ »
// keeps its own href.
//
//   <span data-controller="bridge--overflow-menu" data-bridge--overflow-menu-title-value="Ranger le linge">
//     <a href="/journal/1/edit" data-action="click->bridge--overflow-menu#open">⋯</a>
//     <span hidden>
//       <a href="/journal/1/edit" data-bridge--overflow-menu-target="item">Corriger</a>
//       <a href="/journal/1/delete" data-bridge--overflow-menu-target="item" data-destructive="true">Supprimer</a>
//     </span>
//   </span>
//
// Native reply data: { selectedIndex } (absent when cancelled).
export default class extends BridgeComponent {
  static component = "overflow-menu"
  static targets = ["item"]
  static values = { title: String }

  open(event) {
    if (!this.enabled) return
    event.preventDefault()

    const items = this.itemTargets.map((item, index) => ({
      title: item.textContent.trim(),
      index,
      destructive: item.dataset.destructive === "true"
    }))
    this.send("show", { title: this.titleValue, items }, (message) => {
      const item = this.itemTargets[message.data.selectedIndex]
      if (item) item.click()
    })
  }
}

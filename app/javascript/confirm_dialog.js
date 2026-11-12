import { Turbo } from "@hotwired/turbo-rails"
import { bridge, nativeSupports } from "native_bridge"

// Remplace la boîte confirm() du navigateur par une feuille <dialog>
// (components/_confirm_dialog.html.erb). Turbo l'appelle pour chaque
// data-turbo-confirm. Les deux boutons ont le même poids visuel.
//
// Dans les coquilles natives qui le proposent (composant bridge « confirm »,
// lot 9), la confirmation est une alerte native avec les mêmes libellés.
function confirmWithDialog(message) {
  const dialog = document.getElementById("confirm-dialog")

  if (nativeSupports("confirm")) {
    return new Promise((resolve) => {
      bridge.send({
        component: "confirm",
        event: "show",
        data: {
          message,
          confirmLabel: dialog?.dataset.confirmLabel || "OK",
          cancelLabel: dialog?.dataset.cancelLabel || "Annuler"
        },
        callback: (reply) => resolve(reply.data.confirmed === true)
      })
    })
  }

  if (!dialog || typeof dialog.showModal !== "function") {
    return Promise.resolve(window.confirm(message))
  }

  dialog.querySelector("[data-confirm-message]").textContent = message

  return new Promise((resolve) => {
    dialog.addEventListener("close", () => resolve(dialog.returnValue === "confirm"), { once: true })
    dialog.returnValue = "cancel"
    dialog.showModal()
    dialog.querySelector("[data-confirm-cancel]").focus()
  })
}

if (Turbo.config?.forms) {
  Turbo.config.forms.confirm = confirmWithDialog
} else {
  Turbo.setConfirmMethod(confirmWithDialog)
}

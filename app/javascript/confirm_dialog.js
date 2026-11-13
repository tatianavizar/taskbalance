import { Turbo } from "@hotwired/turbo-rails"

// Remplace la boîte confirm() du navigateur par une feuille <dialog>
// (components/_confirm_dialog.html.erb). Turbo l'appelle pour chaque
// data-turbo-confirm. Les deux boutons ont le même poids visuel.
function confirmWithDialog(message) {
  const dialog = document.getElementById("confirm-dialog")
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

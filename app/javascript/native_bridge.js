import { Controller } from "@hotwired/stimulus"

// The web half of the Hotwire Native bridge (lot 9), written here because the
// official package (@hotwired/hotwire-native-bridge) cannot be downloaded in
// this environment. It follows the same protocol as version 1.x of that
// package, so the native libraries talk to it unchanged:
//
//   - the page exposes `window.HotwireNative.web` and fires
//     `web-bridge:ready` on `document`;
//   - the native side installs an adapter with `setAdapter(adapter)`
//     (`adapter.platform`, `adapter.supportedComponents`,
//     `adapter.supportsComponent(name)`, `adapter.receive(message)`);
//   - a message is `{ id, component, event, data }`; the native side replies
//     with `HotwireNative.web.receive(message)`, same id.
//
// To use the official package instead: `bin/importmap pin
// @hotwired/hotwire-native-bridge`, then import `BridgeComponent` from it in
// app/javascript/controllers/bridge/*.js and delete this file
// (native/README.md, « Pont web »).

class Bridge {
  #adapter = null
  #lastMessageId = 0
  #pendingMessages = []
  #pendingCallbacks = new Map()

  start() {
    document.dispatchEvent(new Event("web-bridge:ready"))
  }

  supportsComponent(component) {
    return this.#adapter ? this.#adapter.supportsComponent(component) : false
  }

  send({ component, event, data, callback }) {
    if (!this.#adapter) {
      this.#pendingMessages.push({ component, event, data, callback })
      return null
    }
    if (!this.supportsComponent(component)) return null

    const id = (++this.#lastMessageId).toString()
    this.#adapter.receive({ id, component, event, data: data || {} })
    if (callback) this.#pendingCallbacks.set(id, callback)
    return id
  }

  receive(message) {
    const callback = this.#pendingCallbacks.get(message.id)
    if (callback) callback(message)
  }

  removeCallbackFor(messageId) {
    this.#pendingCallbacks.delete(messageId)
  }

  removePendingMessagesFor(component) {
    this.#pendingMessages = this.#pendingMessages.filter((message) => message.component !== component)
  }

  setAdapter(adapter) {
    this.#adapter = adapter
    document.documentElement.dataset.bridgePlatform = adapter.platform
    this.adapterDidUpdateSupportedComponents()
    const pending = this.#pendingMessages
    this.#pendingMessages = []
    pending.forEach((message) => this.send(message))
  }

  adapterDidUpdateSupportedComponents() {
    if (this.#adapter) {
      document.documentElement.dataset.bridgeComponents = this.#adapter.supportedComponents.join(" ")
    }
  }
}

if (!window.HotwireNative) {
  const web = new Bridge()
  window.HotwireNative = { web }
  web.start()
}

export const bridge = window.HotwireNative.web

// True once the native shell said it handles this component.
export function nativeSupports(component) {
  return bridge.supportsComponent(component)
}

// Base class of the bridge Stimulus controllers. Messages sent before the
// native adapter is installed wait for it, and are dropped if the shell does
// not know the component (in a regular browser, nothing ever answers).
export class BridgeComponent extends Controller {
  static component = ""

  initialize() {
    this.pendingMessageIds = []
  }

  disconnect() {
    this.pendingMessageIds.forEach((id) => bridge.removeCallbackFor(id))
    this.pendingMessageIds = []
    bridge.removePendingMessagesFor(this.component)
  }

  get component() {
    return this.constructor.component
  }

  get enabled() {
    return bridge.supportsComponent(this.component)
  }

  send(event, data = {}, callback) {
    data.metadata = { url: window.location.href }
    const id = bridge.send({ component: this.component, event, data, callback })
    if (id && callback) this.pendingMessageIds.push(id)
    return id
  }
}

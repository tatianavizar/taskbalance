import HotwireNative
import UIKit

/// « push-notifications » (app/javascript/controllers/bridge/push_notifications_controller.js).
///   connect -> the current state, no prompt (the layout registers the token)
///   request -> the system prompt (H1, « Activer »), then the state
/// Reply: PushState { permission, token, platform, previousToken }.
final class PushNotificationsComponent: BridgeComponent {
    override class var name: String { "push-notifications" }

    override func onReceive(message: Message) {
        let event = message.event
        switch event {
        case "connect":
            PushManager.shared.state { [weak self] state in self?.answer(event, with: state) }
        case "request":
            PushManager.shared.requestPermission { [weak self] state in self?.answer(event, with: state) }
        default:
            break
        }
    }
}

/// « settings »: this app's page in the phone's settings (notifications).
final class SettingsComponent: BridgeComponent {
    override class var name: String { "settings" }

    override func onReceive(message: Message) {
        guard message.event == "open" else { return }
        let address: String
        if #available(iOS 16.0, *) {
            address = UIApplication.openNotificationSettingsURLString
        } else {
            address = UIApplication.openSettingsURLString
        }
        if let url = URL(string: address) {
            UIApplication.shared.open(url)
        }
    }
}

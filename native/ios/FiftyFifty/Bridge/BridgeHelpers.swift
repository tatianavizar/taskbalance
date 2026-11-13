import HotwireNative
import UIKit

extension UIApplication {
    /// The view controller on screen, to present alerts and sheets from a
    /// bridge component without depending on the destination API.
    var topViewController: UIViewController? {
        let window = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while true {
            if let presented = top?.presentedViewController {
                top = presented
            } else if let tabs = top as? UITabBarController, let selected = tabs.selectedViewController {
                top = selected
            } else if let navigation = top as? UINavigationController, let visible = navigation.visibleViewController, visible !== navigation {
                top = visible
            } else {
                return top
            }
        }
    }
}

extension BridgeComponent {
    /// Replies on the main actor. Written `try? await` so it compiles whether
    /// the library's `reply(to:with:)` is synchronous or async/throwing
    /// (the signature changed between Strada and Hotwire Native releases; at
    /// worst the compiler warns).
    func answer<T: Encodable>(_ event: String, with data: T) {
        Task { @MainActor in
            _ = try? await self.reply(to: event, with: data)
        }
    }
}

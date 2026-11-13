import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

/// What the `push-notifications` bridge component answers to the page.
struct PushState: Encodable {
    /// "granted", "denied" or "not_determined".
    let permission: String
    /// The FCM registration token, when granted.
    let token: String?
    let platform: String = "ios"
    /// The token this phone had before the permission was withdrawn: the page
    /// asks the server to forget it.
    let previousToken: String?
}

/// Permission, FCM token and notification taps (lot 8b).
///
/// Push goes through Firebase Cloud Messaging on both platforms: APNs gives
/// the device token to Firebase, Firebase gives an FCM token, and that token
/// is what the server stores (PushDevice) and sends to.
///
/// The token is kept in UserDefaults so H1 can run before sign-up: the
/// layout's bridge element sends it to the server once the person is signed in.
final class PushManager: NSObject {
    static let shared = PushManager()

    private let tokenKey = "push.fcmToken"
    private var firebaseReady = false
    private var tokenWaiters: [(String?) -> Void] = []

    /// Set by SceneDelegate; a tap that came before is kept until then.
    var onOpen: ((URL) -> Void)? {
        didSet {
            if let url = pendingURL, let onOpen {
                pendingURL = nil
                onOpen(url)
            }
        }
    }
    private var pendingURL: URL?

    func configure() {
        // Without GoogleService-Info.plist (not committed), the app runs
        // without push: the server falls back on email.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            firebaseReady = true
        }
        UNUserNotificationCenter.current().delegate = self

        // Already allowed: register again at each launch, which refreshes the token.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func didRegister(deviceToken: Data) {
        guard firebaseReady else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - For the bridge component

    /// The system prompt (H1, « Activer »), then the state.
    func requestPermission(completion: @escaping (PushState) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted { UIApplication.shared.registerForRemoteNotifications() }
                self.state(completion: completion)
            }
        }
    }

    /// The current state, without prompting.
    func state(completion: @escaping (PushState) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.currentToken { token in
                        completion(PushState(permission: "granted", token: token, previousToken: nil))
                    }
                case .denied:
                    completion(PushState(permission: "denied", token: nil, previousToken: self.forgetToken()))
                default:
                    completion(PushState(permission: "not_determined", token: nil, previousToken: self.forgetToken()))
                }
            }
        }
    }

    // MARK: - Token

    private var storedToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    private func store(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    /// Returns the last known token and forgets it.
    private func forgetToken() -> String? {
        let token = storedToken
        UserDefaults.standard.removeObject(forKey: tokenKey)
        return token
    }

    /// The FCM token. Right after the first permission, Firebase may not have
    /// the APNs token yet: wait for `didReceiveRegistrationToken` (10 s at most).
    private func currentToken(completion: @escaping (String?) -> Void) {
        guard firebaseReady else {
            completion(nil)
            return
        }
        Messaging.messaging().token { token, _ in
            DispatchQueue.main.async {
                if let token {
                    self.store(token)
                    completion(token)
                    return
                }
                self.tokenWaiters.append(completion)
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { self.flushWaiters(with: self.storedToken) }
            }
        }
    }

    private func flushWaiters(with token: String?) {
        let waiters = tokenWaiters
        tokenWaiters = []
        waiters.forEach { $0(token) }
    }
}

extension PushManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async {
            if let fcmToken { self.store(fcmToken) }
            self.flushWaiters(with: fcmToken)
        }
    }
}

extension PushManager: UNUserNotificationCenterDelegate {
    /// Shown even when the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// A tap: the payload's "path" is /notifications/:id, which marks it read
    /// and redirects to its screen (NotificationsController#show).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let path = userInfo["path"] as? String, path.hasPrefix("/") {
            let url = AppConfig.url(for: path)
            DispatchQueue.main.async {
                if let onOpen = self.onOpen {
                    onOpen(url)
                } else {
                    self.pendingURL = url
                }
            }
        }
        completionHandler()
    }
}

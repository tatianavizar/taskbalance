import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let tabBarController = MainTabBarController()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabBarController
        window.tintColor = UIColor(red: 0.06, green: 0.10, blue: 0.08, alpha: 1) // ink
        window.makeKeyAndVisible()
        self.window = window

        tabBarController.start()

        // A tapped notification (cold start included: PushManager keeps it until now).
        PushManager.shared.onOpen = { [weak self] url in
            self?.tabBarController.open(url)
        }

        // A universal link that launched the app.
        if let activity = connectionOptions.userActivities.first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb }),
           let url = activity.webpageURL {
            tabBarController.open(url)
        }
    }

    /// A universal link while the app runs (invitation, password reset,
    /// confirmation, notification emails). The server lists them in
    /// apple-app-site-association (NativeApp::LINK_PATHS).
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else { return }
        tabBarController.open(url)
    }
}

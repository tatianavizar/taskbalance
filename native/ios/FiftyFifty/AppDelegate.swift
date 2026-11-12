import HotwireNative
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureHotwire()
        PushManager.shared.configure()
        return true
    }

    // MARK: - Push (APNs -> Firebase)

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushManager.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Simulator without push support, or a signing issue (aps-environment).
        print("APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: - Hotwire Native

    private func configureHotwire() {
        // The bundled copy first (works offline at first launch), then the
        // server's, which wins once loaded (ConfigurationsController).
        var sources: [PathConfiguration.Source] = []
        if let local = Bundle.main.url(forResource: "path-configuration", withExtension: "json") {
            sources.append(.file(local))
        }
        sources.append(.server(AppConfig.url(for: "/configurations/ios_v1.json")))
        Hotwire.loadPathConfiguration(from: sources)

        // Names must match the web controllers in app/javascript/controllers/bridge/.
        Hotwire.registerBridgeComponents([
            PushNotificationsComponent.self,
            SettingsComponent.self,
            DatePickerComponent.self,
            OverflowMenuComponent.self,
            ConfirmComponent.self
        ])

        // The library appends "Hotwire Native iOS; Turbo Native iOS;" and the
        // bridge components: that is what `hotwire_native_app?` detects.
        Hotwire.config.applicationUserAgentPrefix = "50-50 iOS;"
        Hotwire.config.backButtonDisplayMode = .minimal
        Hotwire.config.showDoneButtonOnModals = true
        #if DEBUG
        Hotwire.config.debugLoggingEnabled = true
        #endif
    }
}

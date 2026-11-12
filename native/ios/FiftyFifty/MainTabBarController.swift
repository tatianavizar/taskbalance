import HotwireNative
import UIKit

/// The four tabs of the web app (Accueil, Tâches, Bilan, Foyer), each with
/// its own Hotwire Navigator and navigation stack. The HTML tab bar is hidden
/// in the shells (`hotwire_native_app?`). The same list is in
/// ConfigurationsController::TABS.
final class MainTabBarController: UITabBarController, UITabBarControllerDelegate {
    struct Tab {
        let title: String
        let systemImage: String
        let path: String
        /// Paths that belong to this tab when opened from a link or a notification.
        let prefixes: [String]
    }

    static let tabs: [Tab] = [
        Tab(title: "Accueil", systemImage: "house", path: "/dashboard", prefixes: ["/dashboard", "/absences", "/notifications"]),
        Tab(title: "Tâches", systemImage: "checklist", path: "/chores", prefixes: ["/chores", "/journal"]),
        Tab(title: "Bilan", systemImage: "chart.bar", path: "/bilan", prefixes: ["/bilan", "/niveaux"]),
        Tab(title: "Foyer", systemImage: "person.2", path: "/foyer", prefixes: ["/foyer", "/households", "/pauses"])
    ]

    private var navigators: [Navigator] = []
    private var started: Set<Int> = []

    func start() {
        delegate = self
        navigators = Self.tabs.enumerated().map { index, tab in
            let navigator = Navigator(configuration: .init(name: "tab-\(index)", startLocation: AppConfig.url(for: tab.path)))
            navigator.rootViewController.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.systemImage),
                tag: index
            )
            return navigator
        }
        viewControllers = navigators.map { $0.rootViewController }
        startTab(0)
    }

    /// Opens a URL of the app in the tab it belongs to; any other URL in Safari.
    func open(_ url: URL) {
        guard AppConfig.isOwn(url) else {
            UIApplication.shared.open(url)
            return
        }
        let index = Self.tabs.firstIndex { tab in tab.prefixes.contains { url.path.hasPrefix($0) } } ?? 0
        selectedIndex = index
        startTab(index) // the tab's root first, so « back » leads somewhere
        navigators[index].route(url)
    }

    // Tabs load on first selection, not all four at launch.
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        startTab(selectedIndex)
    }

    private func startTab(_ index: Int) {
        guard index < navigators.count, !started.contains(index) else { return }
        started.insert(index)
        navigators[index].start()
    }
}

import Foundation

/// Where the Rails app lives. `BASE_URL` comes from the build settings
/// (project.yml: production for Release, localhost for Debug) via Info.plist.
enum AppConfig {
    static let baseURL: URL = {
        let value = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String
        return URL(string: value ?? "") ?? URL(string: "https://cinquante.app")!
    }()

    /// An absolute URL for a server path ("/dashboard").
    static func url(for path: String) -> URL {
        URL(string: path, relativeTo: baseURL)?.absoluteURL ?? baseURL
    }

    /// Only links of our own host are opened inside the app.
    static func isOwn(_ url: URL) -> Bool {
        url.host == baseURL.host
    }
}

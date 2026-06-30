import Foundation

/// Shared storage location for media (photos, reels) that both the app and the widget/Live
/// Activity extension can read. Large media lives here as files; only metadata + thumbnails
/// live in SwiftData.
enum AppGroup {
    static let identifier = "group.com.sviftstudios.Grow"

    /// Root of the shared container, or the app's own documents dir as a fallback
    /// (e.g. before the App Group capability is provisioned).
    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var photosDirectory: URL { subdirectory("Photos") }
    static var reelsDirectory: URL { subdirectory("Reels") }

    private static func subdirectory(_ name: String) -> URL {
        let url = containerURL.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Shared UserDefaults the widget reads for scalar twin/streak state.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

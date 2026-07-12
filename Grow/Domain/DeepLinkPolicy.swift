import Foundation

enum DeepLinkDestination: Equatable {
    case today
    case capture
}

enum DeepLinkPolicy {
    static func destination(for url: URL) -> DeepLinkDestination? {
        guard url.scheme?.lowercased() == "grow" else { return nil }

        return switch url.host?.lowercased() {
        case "today": .today
        case "capture": .capture
        default: nil
        }
    }
}

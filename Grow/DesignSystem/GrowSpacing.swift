import SwiftUI

/// Spacing scale + corner radii. Use these instead of magic numbers so layout stays consistent.
enum GrowSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    /// Minimum tappable target (Apple HIG).
    static let touchTargetMin: CGFloat = 44
}

enum GrowRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let pill: CGFloat = 999
}

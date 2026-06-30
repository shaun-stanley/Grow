import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Grow's "Living Field Journal" color system.
///
/// Warm pressed-paper grounds (a naturalist's seed catalog), deep botanical-forest ink,
/// a confident grass green, and a single warm apricot "grow-light" sun reserved for
/// reward / harvest moments. Light is the hero; dark is a warm botanical night (never a
/// flat charcoal). Every surface/ink token is adaptive — reach for a semantic token,
/// never a raw `Color(hex:)` in a view.
enum GrowPalette {

    // MARK: Botanical green ramp (works on both appearances)

    static let sprout50 = hex(0xEAF4E4)
    static let sprout100 = hex(0xCDE7BE)
    static let sprout300 = hex(0x8DCB7C)
    static let sprout500 = hex(0x3E9E4F) // confident grass — primary actions
    static let sprout600 = hex(0x2C7C3C) // pressed / borders
    static let sprout800 = hex(0x16431F) // deep forest — text on tints

    // MARK: Paper & ink (warm, tactile — never clinical gray / flat black)

    /// App background — pressed parchment in light, warm botanical night in dark.
    static let ground = adaptive(light: 0xF3ECDC, dark: 0x12150E)
    /// Slightly raised page (grouped sections).
    static let groundRaised = adaptive(light: 0xFAF4E8, dark: 0x1B1F14)
    /// Card / vessel surface.
    static let surface = adaptive(light: 0xFFFCF5, dark: 0x232A1A)

    /// Primary ink — deep forest in light, warm bone in dark.
    static let textPrimary = adaptive(light: 0x223024, dark: 0xF0EAD9)
    /// Secondary ink — sage.
    static let textSecondary = adaptive(light: 0x6E7A66, dark: 0xA7AE93)
    /// Hairline rules (journal margins, dividers).
    static let separator = adaptive(light: 0xDDD3C0, dark: 0x33402B)

    // MARK: Bloom — the one warm accent (harvest, rewards, the CTA, the mascot soul)

    static let bloom = hex(0xF0A04A)
    /// Ink on a Bloom fill (white fails contrast on soft warm fills).
    static let bloomInk = hex(0x4D2A06)
    /// The radial "grow-light" sun behind the plant.
    static let sunGlow = hex(0xFFCB73)

    // MARK: Plant-health semantics (always paired with a glyph + label, never color alone)

    static let healthy = hex(0x3E9E4F)
    static let thirsty = hex(0x4E9DB0) // water-blue
    static let hungry = hex(0xE0A93E)  // golden (nutrient)
    static let needsCare = hex(0xD2693F) // terracotta
    static let info = hex(0x4E9DB0)

    // MARK: Mascot ("Sprout") — cool green gel body, warm glowing soul

    static let sproutBody = hex(0x8DCB7C)
    static let sproutGlow = hex(0xFFCB73)
    static let sproutInk = hex(0x18331E)

    static let accent = sprout500

    // MARK: - Builders

    static func hex(_ value: UInt32, alpha: Double = 1) -> Color {
        Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: alpha
        )
    }

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

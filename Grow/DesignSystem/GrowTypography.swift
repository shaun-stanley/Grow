import SwiftUI

/// Grow's editorial type system: a characterful **serif** (New York) for display,
/// headlines, and big day-numerals — paired with warm **SF Pro Rounded** for UI labels
/// and body. Plus letter-spaced "field labels" that read like annotations in a seed
/// catalog. Everything is Dynamic Type-relative.
enum GrowType {

    // MARK: Serif — editorial voice (New York)

    /// Big hero headline (e.g. "Let's grow something").
    static func serifTitle(_ weight: Font.Weight = .semibold) -> Font {
        .system(.largeTitle, design: .serif).weight(weight)
    }

    static func serifHeadline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.title2, design: .serif).weight(weight)
    }

    /// Oversized day-counter numeral — the signature editorial moment.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    // MARK: Rounded — friendly UI voice (SF Pro Rounded)

    static func title(_ weight: Font.Weight = .semibold) -> Font {
        .system(.title3, design: .rounded).weight(weight)
    }

    static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.headline, design: .rounded).weight(weight)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(.callout, design: .rounded).weight(weight)
    }

    static func callout(_ weight: Font.Weight = .medium) -> Font {
        .system(.subheadline, design: .rounded).weight(weight)
    }

    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .system(.caption, design: .rounded).weight(weight)
    }
}

extension Text {
    /// Applies a Grow type token + color in one call.
    func growStyle(_ font: Font, color: Color = GrowPalette.textPrimary) -> some View {
        self.font(font).foregroundStyle(color)
    }

    /// A field-journal annotation: tiny, uppercase, letter-spaced, sage.
    func fieldLabel(color: Color = GrowPalette.textSecondary) -> some View {
        self
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .textCase(.uppercase)
            .kerning(1.6)
            .foregroundStyle(color)
    }
}

/// A thin journal hairline rule.
struct Hairline: View {
    var color: Color = GrowPalette.separator
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

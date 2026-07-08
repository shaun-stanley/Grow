import SwiftUI

/// Grow's type system uses Apple's default system font for every display and UI role.
/// Text styles stay Dynamic Type-relative, while sizing/weight carry hierarchy.
enum GrowType {

    // MARK: Display

    /// Big hero headline (e.g. "Let's grow something").
    static func displayTitle(_ weight: Font.Weight = .semibold) -> Font {
        .system(.largeTitle, design: .default).weight(weight)
    }

    static func displayHeadline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.title2, design: .default).weight(weight)
    }

    /// Oversized day-counter numeral using the same native system family.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func receiptValue(_ size: CGFloat = 30, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: UI

    static func title(_ weight: Font.Weight = .semibold) -> Font {
        .system(.title3, design: .default).weight(weight)
    }

    static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.headline, design: .default).weight(weight)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(.callout, design: .default).weight(weight)
    }

    static func callout(_ weight: Font.Weight = .medium) -> Font {
        .system(.subheadline, design: .default).weight(weight)
    }

    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .system(.caption, design: .default).weight(weight)
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
            .font(.system(.caption2, design: .default).weight(.semibold))
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

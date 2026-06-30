import SwiftUI

/// Grow's functional "glass" layer (tab bar chrome, action capsules, stat pills, capture HUD).
/// Glass lives ONLY in the functional layer — never on the plant/content itself.
/// Respects Reduce Transparency by falling back to a solid surface.
private struct GrowGlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat
    var tint: Color?

    func body(content: Content) -> some View {
        content
            .background {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                if reduceTransparency {
                    shape.fill(GrowPalette.surface)
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            }
            .overlay {
                if let tint {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(reduceTransparency ? 0.18 : 0.12))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(reduceTransparency ? 0 : 0.18), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// Apply Grow's glass surface to functional chrome.
    func growGlass(cornerRadius: CGFloat = GrowRadius.md, tint: Color? = nil) -> some View {
        modifier(GrowGlassSurface(cornerRadius: cornerRadius, tint: tint))
    }
}

/// A reusable padded glass card for functional content.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = GrowRadius.lg
    var tint: Color?
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(GrowSpacing.md)
            .growGlass(cornerRadius: cornerRadius, tint: tint)
    }
}

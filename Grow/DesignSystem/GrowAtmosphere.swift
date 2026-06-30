import SwiftUI

/// Warm "pressed paper" page background: a soft top-light wash, an ultra-faint speckle
/// grain for tactility, and a gentle vignette so content floats. This is what makes the
/// app feel like a printed field journal rather than a flat screen.
struct PaperBackground: View {
    /// 0 = none, 1 = full grow-light bloom from the top.
    var light: Double = 0.5

    var body: some View {
        ZStack {
            GrowPalette.ground

            // Warm light pooling from the top — the "grow light".
            LinearGradient(
                colors: [
                    GrowPalette.sunGlow.opacity(0.16 * light),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            // Soft vignette to seat the page.
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.06)],
                center: .center,
                startRadius: 220,
                endRadius: 560
            )
            .blendMode(.multiply)

            PaperGrain()
                .opacity(0.05)
                .blendMode(.softLight)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

/// Deterministic speckle texture (seeded, so it never flickers on redraw).
private struct PaperGrain: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededRNG(seed: 0xBADA55)
            let count = Int((size.width * size.height) / 900)
            for _ in 0..<count {
                let x = rng.nextDouble() * size.width
                let y = rng.nextDouble() * size.height
                let r = 0.4 + rng.nextDouble() * 0.7
                let shade = rng.nextDouble() > 0.5 ? Color.white : Color.black
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(Path(ellipseIn: rect), with: .color(shade.opacity(0.5)))
            }
        }
        .drawingGroup()
    }
}

/// The apricot grow-light bloom that sits behind the plant specimen.
struct GrowLightGlow: View {
    var intensity: Double = 1
    var size: CGFloat = 280

    var body: some View {
        RadialGradient(
            colors: [
                GrowPalette.sunGlow.opacity(0.55 * intensity),
                GrowPalette.bloom.opacity(0.18 * intensity),
                .clear
            ],
            center: .center,
            startRadius: 4,
            endRadius: size * 0.62
        )
        .frame(width: size, height: size)
        .blur(radius: 8)
        .allowsHitTesting(false)
    }
}

/// Tiny, deterministic linear-congruential RNG so textures are stable across redraws.
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

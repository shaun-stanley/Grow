import SwiftUI

/// A hand-drawn-feeling seedling rendered procedurally, so it grows with the real plant.
/// `progress` 0…1 maps germination → harvest: taller stem, more leaf pairs, and a bloom
/// at the top once it flowers. `phase` drives a gentle living sway.
struct PlantIllustration: View {
    var progress: Double
    var hasBloom: Bool = false
    var tint: Color = GrowPalette.sprout500
    var phase: Double = 0

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = w * 0.5
            let baseY = h * 0.98
            let p = max(0.06, min(1, progress))
            let topY = baseY - h * (0.18 + 0.72 * p)
            let sway = phase

            // Stem — a soft S-curve, tapering as it rises.
            let ctrl1 = CGPoint(x: cx - w * 0.06 + CGFloat(sin(sway)) * 4, y: baseY - (baseY - topY) * 0.45)
            let ctrl2 = CGPoint(x: cx + w * 0.07 + CGFloat(sin(sway + 1)) * 5, y: baseY - (baseY - topY) * 0.8)
            let tip = CGPoint(x: cx + CGFloat(sin(sway + 0.6)) * 6, y: topY)
            var stem = Path()
            stem.move(to: CGPoint(x: cx, y: baseY))
            stem.addCurve(to: tip, control1: ctrl1, control2: ctrl2)
            ctx.stroke(
                stem,
                with: .linearGradient(
                    Gradient(colors: [GrowPalette.sprout600, tint]),
                    startPoint: CGPoint(x: cx, y: baseY),
                    endPoint: tip
                ),
                style: StrokeStyle(lineWidth: max(2, 5 * p), lineCap: .round)
            )

            // Leaf pairs climbing the stem; lower leaves are larger.
            let pairs = max(1, Int((p * 4).rounded()))
            for i in 0..<pairs {
                let t = Double(i + 1) / Double(pairs + 1)
                let attach = pointOnCurve(t, p0: CGPoint(x: cx, y: baseY), c1: ctrl1, c2: ctrl2, p1: tip)
                let length = h * 0.17 * (0.55 + 0.45 * p) * (1.0 - 0.3 * t)
                let flutter = CGFloat(sin(sway * 1.3 + Double(i))) * 0.06
                drawLeaf(ctx, at: attach, length: length, angle: -.pi / 2 - .pi * 0.36 + flutter, tint: tint)
                drawLeaf(ctx, at: attach, length: length, angle: -.pi / 2 + .pi * 0.36 + flutter, tint: tint)
            }

            // A tender new shoot at the very top.
            if p > 0.2 {
                drawLeaf(ctx, at: tip, length: h * 0.09 * p, angle: -.pi / 2 + CGFloat(sin(sway)) * 0.1, tint: GrowPalette.sprout300)
            }

            // A bloom once flowering.
            if hasBloom {
                let bloomR = h * 0.045
                for k in 0..<6 {
                    let a = Double(k) / 6 * .pi * 2 + sway * 0.2
                    let petal = CGRect(
                        x: tip.x + CGFloat(cos(a)) * bloomR - bloomR * 0.6,
                        y: tip.y - h * 0.04 + CGFloat(sin(a)) * bloomR - bloomR * 0.6,
                        width: bloomR * 1.2, height: bloomR * 1.2
                    )
                    ctx.fill(Path(ellipseIn: petal), with: .color(GrowPalette.bloom.opacity(0.92)))
                }
                let center = CGRect(x: tip.x - bloomR * 0.4, y: tip.y - h * 0.04 - bloomR * 0.4, width: bloomR * 0.8, height: bloomR * 0.8)
                ctx.fill(Path(ellipseIn: center), with: .color(GrowPalette.sunGlow))
            }
        }
    }

    private func drawLeaf(_ ctx: GraphicsContext, at point: CGPoint, length: CGFloat, angle: CGFloat, tint: Color) {
        let dir = CGVector(dx: cos(angle), dy: sin(angle))
        let perp = CGVector(dx: -dir.dy, dy: dir.dx)
        let tip = CGPoint(x: point.x + dir.dx * length, y: point.y + dir.dy * length)
        let mid = CGPoint(x: point.x + dir.dx * length * 0.5, y: point.y + dir.dy * length * 0.5)
        let wdt = length * 0.4
        let c1 = CGPoint(x: mid.x + perp.dx * wdt, y: mid.y + perp.dy * wdt)
        let c2 = CGPoint(x: mid.x - perp.dx * wdt, y: mid.y - perp.dy * wdt)

        var leaf = Path()
        leaf.move(to: point)
        leaf.addQuadCurve(to: tip, control: c1)
        leaf.addQuadCurve(to: point, control: c2)
        ctx.fill(
            leaf,
            with: .linearGradient(
                Gradient(colors: [tint.opacity(0.95), GrowPalette.sprout300]),
                startPoint: point, endPoint: tip
            )
        )
        var vein = Path()
        vein.move(to: point)
        vein.addLine(to: tip)
        ctx.stroke(vein, with: .color(GrowPalette.sprout800.opacity(0.35)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
    }

    private func pointOnCurve(_ t: Double, p0: CGPoint, c1: CGPoint, c2: CGPoint, p1: CGPoint) -> CGPoint {
        let mt = 1 - t
        let a = mt * mt * mt
        let b = 3 * mt * mt * t
        let c = 3 * mt * t * t
        let d = t * t * t
        return CGPoint(
            x: a * p0.x + b * c1.x + c * c2.x + d * p1.x,
            y: a * p0.y + b * c1.y + c * c2.y + d * p1.y
        )
    }
}

/// The living twin's vessel: an apricot grow-light bloom, a glass jar with a water line and
/// clay pebbles, the procedural plant, and ambient drifting motes. The whole composition
/// breathes (gated by Reduce Motion).
struct SpecimenJar: View {
    var progress: Double
    var hasBloom: Bool = false
    var tint: Color = GrowPalette.sprout500
    var size: CGFloat = 240

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
            ZStack {
                GrowLightGlow(intensity: 0.5 + 0.5 * progress, size: size * 1.5)
                    .offset(y: -size * 0.18)

                // Glass vessel.
                JarGlass()
                    .frame(width: size * 0.78, height: size * 0.92)

                // Water + clay pebbles + plant, clipped to the jar interior.
                ZStack(alignment: .bottom) {
                    // Water fill.
                    RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [GrowPalette.info.opacity(0.16), GrowPalette.info.opacity(0.28)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(height: size * 0.3)

                    ClayPebbles(width: size * 0.7)
                        .frame(height: size * 0.16)

                    PlantIllustration(
                        progress: progress,
                        hasBloom: hasBloom,
                        tint: tint,
                        phase: sin(phase * 0.6) * 0.5
                    )
                    .frame(width: size * 0.66, height: size * 0.82)
                    .offset(y: -size * 0.1)
                }
                .frame(width: size * 0.7, height: size * 0.88)
                .clipShape(JarShape())
                .frame(width: size * 0.78, height: size * 0.92)

                Motes(phase: phase)
                    .frame(width: size, height: size)
                    .allowsHitTesting(false)
            }
            .frame(width: size, height: size)
        }
        .accessibilityElement()
        .accessibilityLabel("Your plant, growing")
    }
}

/// The frosted-glass jar silhouette.
private struct JarGlass: View {
    var body: some View {
        JarShape()
            .fill(.ultraThinMaterial)
            .overlay(JarShape().fill(GrowPalette.surface.opacity(0.18)))
            .overlay(
                JarShape().strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            // Specular highlight down the left of the glass.
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 6)
                    .blur(radius: 3)
                    .padding(.vertical, 18)
                    .padding(.leading, 14)
            }
    }
}

/// A rounded jar shape with a slightly tapered neck.
private struct JarShape: InsettableShape {
    var inset: CGFloat = 0
    func inset(by amount: CGFloat) -> some InsettableShape {
        var s = self; s.inset += amount; return s
    }
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        return Path(roundedRect: r, cornerRadius: r.width * 0.22, style: .continuous)
    }
}

/// A little cluster of clay-pebble growing medium at the base.
private struct ClayPebbles: View {
    var width: CGFloat
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 0xC1A7)
            let count = 11
            for _ in 0..<count {
                let d = 8 + rng.nextDouble() * 9
                let x = rng.nextDouble() * (size.width - d)
                let y = size.height - d - rng.nextDouble() * (size.height * 0.5)
                let rect = CGRect(x: x, y: y, width: d, height: d)
                let shade = 0.55 + rng.nextDouble() * 0.3
                ctx.fill(Path(ellipseIn: rect), with: .color(GrowPalette.bloom.opacity(shade * 0.7)))
                ctx.stroke(Path(ellipseIn: rect), with: .color(GrowPalette.bloomInk.opacity(0.15)), lineWidth: 0.6)
            }
        }
        .frame(width: width)
    }
}

/// Slow drifting light motes for atmosphere.
private struct Motes: View {
    var phase: Double
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 0x510B)
            for i in 0..<7 {
                let baseX = rng.nextDouble() * size.width
                let baseY = rng.nextDouble() * size.height
                let drift = sin(phase * 0.3 + Double(i)) * 10
                let r = 1.5 + rng.nextDouble() * 2.5
                let rect = CGRect(x: baseX + drift, y: baseY + cos(phase * 0.2 + Double(i)) * 8, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(GrowPalette.sunGlow.opacity(0.5)))
            }
        }
    }
}

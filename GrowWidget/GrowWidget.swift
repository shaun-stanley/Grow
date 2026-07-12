import SwiftUI
import WidgetKit

struct GrowWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetGrowSnapshot?
}

struct GrowWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GrowWidgetEntry {
        GrowWidgetEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (GrowWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetGrowSnapshot.sample : WidgetSnapshotReader().read()
        completion(GrowWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GrowWidgetEntry>) -> Void) {
        let now = Date()
        let entry = GrowWidgetEntry(date: now, snapshot: WidgetSnapshotReader().read())
        completion(
            Timeline(
                entries: [entry],
                policy: .after(now.addingTimeInterval(30 * 60))
            )
        )
    }
}

@main
struct GrowTwinWidget: Widget {
    private let kind = "com.sviftstudios.Grow.living-twin"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GrowWidgetProvider()) { entry in
            GrowWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.ground }
        }
        .configurationDisplayName("Living Twin")
        .description("See your plant, streak, and next growth memory at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct GrowWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GrowWidgetEntry

    private var snapshot: WidgetGrowSnapshot {
        entry.snapshot ?? .empty
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
        .padding(14)
        .widgetURL(URL(string: entry.snapshot == nil ? "grow://today" : "grow://capture"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            Spacer(minLength: 2)
            WidgetPlantTwin(progress: snapshot.modeledProgress)
                .frame(maxWidth: .infinity)
                .frame(height: 78)
            Spacer(minLength: 2)
            HStack(alignment: .firstTextBaseline) {
                Label("\(snapshot.streakCurrent)", systemImage: "flame.fill")
                    .foregroundStyle(WidgetPalette.bloom)
                Spacer()
                Text("\(Int((snapshot.futureReelProgress * 100).rounded()))% reel")
                    .foregroundStyle(WidgetPalette.secondary)
            }
            .font(.caption.bold())
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                masthead
                Spacer(minLength: 4)
                WidgetPlantTwin(progress: snapshot.modeledProgress)
                    .frame(width: 126, height: 92)
            }

            Rectangle()
                .fill(WidgetPalette.rule)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 7) {
                Label(snapshot.stageDisplayName, systemImage: snapshot.stageSystemImage)
                    .foregroundStyle(WidgetPalette.sprout)
                    .font(.caption.bold())

                Text(snapshot.nextCaptureTitle)
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(1)

                Text(snapshot.nextCaptureBody)
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.secondary)
                    .lineLimit(2)

                Spacer(minLength: 0)

                HStack {
                    Label("\(snapshot.streakCurrent) days", systemImage: "flame.fill")
                        .foregroundStyle(WidgetPalette.bloom)
                    Spacer()
                    Text("\(snapshot.frameCount)/\(snapshot.targetFrameCount) frames")
                        .foregroundStyle(WidgetPalette.secondary)
                }
                .font(.caption.bold())
            }
        }
    }

    private var masthead: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.latinName?.uppercased() ?? "GROW · LIVING TWIN")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(WidgetPalette.secondary)
                    .lineLimit(1)
                Text(snapshot.displayName)
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            VStack(alignment: .trailing, spacing: -2) {
                Text("DAY")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(WidgetPalette.sprout)
                Text("\(snapshot.dayCount)")
                    .font(.system(size: 26, weight: .light, design: .rounded))
                    .foregroundStyle(WidgetPalette.ink)
                    .monospacedDigit()
            }
        }
    }

    private var accessibilitySummary: String {
        guard entry.snapshot != nil else {
            return "Grow widget. Start your first grow."
        }
        return "\(snapshot.displayName), Day \(snapshot.dayCount), \(snapshot.stageDisplayName), \(snapshot.streakCurrent) day streak, \(snapshot.frameCount) frames. \(snapshot.nextCaptureTitle)."
    }
}

private struct WidgetPlantTwin: View {
    let progress: Double

    private var growth: CGFloat {
        CGFloat(min(1, max(0.06, progress)))
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let stemHeight = size * (0.28 + growth * 0.34)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .fill(WidgetPalette.water.opacity(0.18))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                            .stroke(WidgetPalette.rule, lineWidth: 1)
                    }
                    .frame(width: size * 0.74, height: size * 0.56)

                Capsule()
                    .fill(WidgetPalette.sprout)
                    .frame(width: max(3, size * 0.035), height: stemHeight)
                    .offset(y: -size * 0.12)

                leaf(size: size, mirrored: false)
                    .offset(x: -size * 0.13, y: -size * (0.24 + growth * 0.23))
                leaf(size: size, mirrored: true)
                    .offset(x: size * 0.13, y: -size * (0.31 + growth * 0.24))

                HStack(spacing: size * 0.055) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle().fill(WidgetPalette.pebble).frame(width: size * 0.065)
                    }
                }
                .offset(y: -size * 0.08)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetAccentable()
        }
    }

    private func leaf(size: CGFloat, mirrored: Bool) -> some View {
        Ellipse()
            .fill(mirrored ? WidgetPalette.sprout.opacity(0.72) : WidgetPalette.sprout)
            .frame(width: size * 0.24, height: size * 0.12)
            .rotationEffect(.degrees(mirrored ? -28 : 28))
    }
}

private enum WidgetPalette {
    static let ground = Color(red: 0.95, green: 0.92, blue: 0.86)
    static let ink = Color(red: 0.13, green: 0.19, blue: 0.14)
    static let secondary = Color(red: 0.36, green: 0.43, blue: 0.34)
    static let rule = Color(red: 0.78, green: 0.74, blue: 0.66)
    static let sprout = Color(red: 0.17, green: 0.49, blue: 0.24)
    static let bloom = Color(red: 0.94, green: 0.63, blue: 0.29)
    static let water = Color(red: 0.31, green: 0.62, blue: 0.69)
    static let pebble = Color(red: 0.74, green: 0.49, blue: 0.27)
}

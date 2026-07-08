import SwiftUI
import SwiftData
import UIKit

/// Top-level navigation. A Liquid Glass tab bar over the field-journal pages.
struct RootView: View {
    @Environment(GrowStore.self) private var store
    @Environment(PlantCatalogService.self) private var catalog
    @Environment(StreakService.self) private var streakService
    @Environment(WidgetSyncService.self) private var widgetSyncService
    @State private var selectedTab: GrowTab = RootView.initialTab

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "leaf", value: .today) { HomeTwinScreen() }
            Tab("Care", systemImage: "drop", value: .care) { TodayScreen() }
            Tab("Capture", systemImage: "camera", value: .capture) { CaptureScreen() }
            Tab("Reels", systemImage: "play.rectangle", value: .reels) { ReelsScreen() }
            Tab("Dex", systemImage: "square.grid.2x2", value: .dex) { DexScreen() }
        }
        .tint(GrowPalette.sprout600)
        .task {
            syncActiveGrowSnapshot()
        }
    }

    private func syncActiveGrowSnapshot() {
        let activeGrow = store.activeGrows().first
        widgetSyncService.sync(
            activeGrow: activeGrow,
            species: activeGrow.flatMap { catalog.species(id: $0.speciesID) },
            streak: streakService.snapshot()
        )
    }

    private static var initialTab: GrowTab {
        if CommandLine.arguments.contains("-openReels") { return .reels }
        if CommandLine.arguments.contains("-openCapture") { return .capture }
        return .today
    }
}

private enum GrowTab: Hashable {
    case today
    case care
    case capture
    case reels
    case dex
}

// MARK: - Home (the living specimen)

struct HomeTwinScreen: View {
    @Environment(GrowStore.self) private var store
    @Environment(PlantCatalogService.self) private var catalog
    @Environment(StreakService.self) private var streakService
    @Environment(WidgetSyncService.self) private var widgetSyncService
    @Query(
        filter: #Predicate<Grow> { $0.isActive && $0.archivedDate == nil },
        sort: \Grow.startDate, order: .reverse
    ) private var grows: [Grow]

    var body: some View {
        ZStack {
            PaperBackground(light: 0.7)
            if let grow = grows.first {
                ActiveGrowView(grow: grow, species: catalog.species(id: grow.speciesID))
                    .transition(.opacity)
            } else {
                FirstGrowView(speciesCount: catalog.species.count, onPlant: plantFirst)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.6), value: grows.isEmpty)
    }

    private func plantFirst() {
        let pick = catalog.beginnerPicks.first ?? catalog.species.first
        guard let pick else { return }
        let grow = store.createGrow(speciesID: pick.id, nickname: "", system: .kratky)
        widgetSyncService.sync(activeGrow: grow, species: pick, streak: streakService.snapshot())
    }
}

/// The hero state once something is growing — a magazine spread for one plant.
private struct ActiveGrowView: View {
    let grow: Grow
    let species: PlantSpecies?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Masthead.
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(species?.latinName ?? "Specimen")
                        .fieldLabel()
                    Text(grow.nickname.isEmpty ? (species?.commonName ?? "My plant") : grow.nickname)
                        .growStyle(GrowType.displayHeadline())
                }
                Spacer()
                Text(species?.emoji ?? "🌿").font(.title2)
            }
            .growEntrance(0)
            .padding(.horizontal, GrowSpacing.lg)
            .padding(.top, GrowSpacing.sm)

            Spacer(minLength: 0)

            // The specimen, with its day-count set like an editorial folio.
            ZStack(alignment: .topTrailing) {
                SpecimenJar(
                    progress: grow.currentStage.growthProgress,
                    hasBloom: grow.currentStage.hasBloom,
                    size: 300
                )
                .growEntrance(1)

                VStack(alignment: .trailing, spacing: -6) {
                    Text("DAY").fieldLabel(color: GrowPalette.sprout600)
                    Text("\(grow.dayCount)")
                        .growStyle(GrowType.numeral(64), color: GrowPalette.textPrimary)
                }
                .growEntrance(2)
                .offset(x: -8, y: 8)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            // Field entries — the journal's data line.
            VStack(spacing: GrowSpacing.sm) {
                Hairline()
                HStack(alignment: .top, spacing: GrowSpacing.md) {
                    FieldEntry(label: "Stage", value: grow.currentStage.displayName, tint: GrowPalette.healthy)
                    Divider().frame(height: 30)
                    FieldEntry(label: "System", value: grow.system.shortName, tint: GrowPalette.textPrimary)
                    Divider().frame(height: 30)
                    FieldEntry(label: "Harvest", value: species?.harvestText ?? "—", tint: GrowPalette.bloom)
                }
                Hairline()
            }
            .growEntrance(3)
            .padding(.horizontal, GrowSpacing.lg)
            .padding(.bottom, GrowSpacing.md)
        }
        .padding(.bottom, GrowSpacing.sm)
    }
}

/// The first-run hero — a quiet, confident invitation, not a busy empty state.
private struct FirstGrowView: View {
    let speciesCount: Int
    var onPlant: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Grow · a living journal")
                .fieldLabel()
                .growEntrance(0)
                .padding(.horizontal, GrowSpacing.lg)
                .padding(.top, GrowSpacing.md)

            Spacer(minLength: GrowSpacing.lg)

            SpecimenJar(progress: 0.06, size: 300)
                .growEntrance(1)
                .frame(maxWidth: .infinity)

            Spacer(minLength: GrowSpacing.lg)

            VStack(alignment: .leading, spacing: GrowSpacing.sm) {
                Text("Grow something\nfrom almost nothing.")
                    .growStyle(GrowType.displayTitle())
                    .fixedSize(horizontal: false, vertical: true)
                    .growEntrance(2)

                Text("Never grown a thing before? Perfect. Pick a beginner-proof crop, snap a photo a day, and watch it become a time-lapse you'll want to share.")
                    .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .growEntrance(3)

                Button(action: onPlant) {
                    HStack(spacing: GrowSpacing.xs) {
                        Text("Plant your first seed")
                        Image(systemName: "arrow.right")
                    }
                    .font(GrowType.headline())
                    .foregroundStyle(GrowPalette.bloomInk)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(GrowPalette.bloom, in: Capsule())
                    .shadow(color: GrowPalette.bloom.opacity(0.35), radius: 14, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.top, GrowSpacing.xs)
                .growEntrance(4)

                Text("\(speciesCount) beginner-proof crops · no green thumb required")
                    .fieldLabel()
                    .frame(maxWidth: .infinity)
                    .growEntrance(5)
                    .padding(.top, 2)
            }
            .padding(.horizontal, GrowSpacing.lg)
            .padding(.bottom, GrowSpacing.lg)
        }
    }
}

// MARK: - Placeholder pages (cohesive with the journal aesthetic)

struct TodayScreen: View {
    var body: some View { JournalPlaceholder(kicker: "The almanac", title: "Today's care", icon: "drop.fill", note: "Your plant's watering, feeding and pH checks — gathered into a calm daily list.") }
}

struct ReelsScreen: View {
    @Environment(PlantCatalogService.self) private var catalog
    @Environment(ReelRenderingService.self) private var reelRenderingService
    @Query(
        filter: #Predicate<Grow> { $0.isActive && $0.archivedDate == nil },
        sort: \Grow.startDate, order: .reverse
    ) private var grows: [Grow]

    var body: some View {
        ZStack {
            PaperBackground(light: 0.48)
            if let grow = grows.first {
                ReelStudio(grow: grow, species: catalog.species(id: grow.speciesID))
                    .environment(reelRenderingService)
            } else {
                FirstReelEmptyState()
            }
        }
    }
}

private struct ReelStudio: View {
    @Environment(ReelRenderingService.self) private var reelRenderingService
    let grow: Grow
    let species: PlantSpecies?

    private var photos: [GrowPhoto] {
        (grow.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }
    }

    private var reels: [Reel] {
        (grow.reels ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GrowSpacing.lg) {
                masthead
                    .growEntrance(0)

                ReelPosterPreview(grow: grow, species: species, latestPhoto: photos.last, frameCount: photos.count)
                    .frame(maxWidth: 258)
                    .frame(maxWidth: .infinity)
                    .growEntrance(1)

                renderControls
                    .growEntrance(2)

                if !reels.isEmpty {
                    renderedReels
                        .growEntrance(3)
                }
            }
            .padding(.horizontal, GrowSpacing.lg)
            .padding(.top, GrowSpacing.lg)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.xs) {
            Text("The reel")
                .fieldLabel()
            HStack(alignment: .firstTextBaseline, spacing: GrowSpacing.sm) {
                Text(displayName)
                    .growStyle(GrowType.displayHeadline())
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: GrowSpacing.sm)
                Text("\(photos.count)")
                    .growStyle(GrowType.numeral(42), color: GrowPalette.sprout600)
                Text("frames")
                    .fieldLabel()
            }
            Hairline()
        }
    }

    private var renderControls: some View {
        VStack(spacing: GrowSpacing.md) {
            HStack(spacing: GrowSpacing.sm) {
                Button {
                    Task {
                        await reelRenderingService.renderPreview(for: grow, species: species)
                    }
                } label: {
                    HStack(spacing: GrowSpacing.xs) {
                        if reelRenderingService.isRendering {
                            ProgressView()
                                .controlSize(.small)
                                .tint(GrowPalette.bloomInk)
                        } else {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                        }
                        Text(reelRenderingService.isRendering ? "Rendering" : "Render preview")
                    }
                    .font(GrowType.headline())
                    .foregroundStyle(GrowPalette.bloomInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(GrowPalette.bloom, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(photos.isEmpty || reelRenderingService.isRendering)
                .opacity(photos.isEmpty ? 0.52 : 1)

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(GrowPalette.sprout800)
                            .frame(width: 52, height: 52)
                            .background(GrowPalette.sprout100, in: Circle())
                    }
                    .accessibilityLabel("Share latest reel")
                }
            }

            if let error = reelRenderingService.lastErrorMessage {
                StatusRow(icon: "exclamationmark.triangle.fill", text: error, tint: GrowPalette.needsCare)
            } else if let result = reelRenderingService.lastResult {
                StatusRow(
                    icon: "checkmark.seal.fill",
                    text: "\(result.frameCount) frames rendered in \(durationText(result.durationSeconds))",
                    tint: GrowPalette.healthy
                )
            } else if photos.isEmpty {
                StatusRow(icon: "camera.fill", text: "Frame 1 is waiting", tint: GrowPalette.info)
            } else {
                StatusRow(icon: "play.rectangle.fill", text: futureReelText, tint: GrowPalette.sprout600)
            }
        }
    }

    private var renderedReels: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.sm) {
            HStack {
                Text("Exports").fieldLabel()
                Spacer()
                Text("\(reels.count)")
                    .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(reels) { reel in
                    ReelExportRow(reel: reel)
                    if reel.id != reels.last?.id {
                        Hairline()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(GrowPalette.surface.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(GrowPalette.separator.opacity(0.74), lineWidth: 1)
            )
        }
    }

    private var shareURL: URL? {
        if let result = reelRenderingService.lastResult {
            return result.outputURL
        }
        guard let latestReel = reels.first, !latestReel.localFileName.isEmpty else { return nil }
        return AppGroup.containerURL.appendingPathComponent(latestReel.localFileName)
    }

    private var displayName: String {
        grow.nickname.isEmpty ? (species?.commonName ?? "My plant") : grow.nickname
    }

    private var futureReelText: String {
        let progress = min(100, Int((Double(photos.count) / 30 * 100).rounded()))
        return "\(progress)% of the first 30-frame reel"
    }

    private func durationText(_ duration: Double) -> String {
        String(format: "%.1fs", duration)
    }
}

private struct ReelPosterPreview: View {
    let grow: Grow
    let species: PlantSpecies?
    let latestPhoto: GrowPhoto?
    let frameCount: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            posterImage
                .frame(maxWidth: .infinity)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipped()

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: GrowSpacing.xs) {
                Text("Future reel")
                    .fieldLabel(color: .white.opacity(0.72))
                Text("Day \(latestPhoto?.dayIndex ?? grow.dayCount)")
                    .growStyle(GrowType.numeral(58), color: .white)
                HStack(spacing: GrowSpacing.xs) {
                    Image(systemName: frameCount > 0 ? "checkmark.seal.fill" : "camera.fill")
                    Text(frameCount > 0 ? "\(frameCount) frames captured" : "Frame 1 is waiting")
                }
                .font(GrowType.callout(.semibold))
                .foregroundStyle(.white.opacity(0.84))

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.28))
                        Capsule()
                            .fill(GrowPalette.bloom)
                            .frame(width: proxy.size.width * min(1, max(0.04, Double(frameCount) / 30)))
                    }
                }
                .frame(height: 9)
                .padding(.top, 4)
            }
            .padding(GrowSpacing.md)
        }
        .background(GrowPalette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(GrowPalette.separator.opacity(0.68), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 20, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reel preview for \(displayName)")
    }

    @ViewBuilder
    private var posterImage: some View {
        if let data = latestPhoto?.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                GrowPalette.groundRaised
                SpecimenJar(
                    progress: grow.currentStage.growthProgress,
                    hasBloom: grow.currentStage.hasBloom,
                    size: 260
                )
            }
        }
    }

    private var displayName: String {
        grow.nickname.isEmpty ? (species?.commonName ?? "My plant") : grow.nickname
    }
}

private struct ReelExportRow: View {
    let reel: Reel

    var body: some View {
        HStack(spacing: GrowSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(GrowPalette.sprout50)
                if let data = reel.posterFrameData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(GrowPalette.sprout600)
                }
            }
            .frame(width: 36, height: 48)
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(reel.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .growStyle(GrowType.callout(.semibold))
                    .lineLimit(1)
                Text("\(reel.photoCount) frames - \(String(format: "%.1fs", reel.durationSeconds))")
                    .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
            }

            Spacer(minLength: GrowSpacing.sm)

            if !reel.localFileName.isEmpty {
                ShareLink(item: AppGroup.containerURL.appendingPathComponent(reel.localFileName)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(GrowPalette.sprout600)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Share reel")
            }
        }
        .padding(.horizontal, GrowSpacing.sm)
        .padding(.vertical, GrowSpacing.xs)
    }
}

private struct StatusRow: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: GrowSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, GrowSpacing.sm)
        .padding(.vertical, 10)
        .background(GrowPalette.surface.opacity(0.76), in: Capsule())
        .overlay(
            Capsule()
                .stroke(GrowPalette.separator.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct FirstReelEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.md) {
            Text("The reel").fieldLabel().growEntrance(0)
            Text("Plant first, then motion follows.")
                .growStyle(GrowType.displayTitle())
                .fixedSize(horizontal: false, vertical: true)
                .growEntrance(1)
            Hairline().growEntrance(2)
            SpecimenJar(progress: 0.08, size: 280)
                .frame(maxWidth: .infinity)
                .growEntrance(3)
            StatusRow(icon: "leaf.fill", text: "No active grow yet", tint: GrowPalette.sprout600)
                .growEntrance(4)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GrowSpacing.lg)
        .padding(.top, GrowSpacing.xl)
    }
}

struct DexScreen: View {
    var body: some View { JournalPlaceholder(kicker: "The herbarium", title: "Your collection", icon: "square.grid.2x2.fill", note: "Every species you've grown, pressed and catalogued. Gotta grow 'em all.") }
}

// MARK: - Shared building blocks

private struct FieldEntry: View {
    let label: String
    let value: String
    var tint: Color = GrowPalette.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).fieldLabel()
            Text(value)
                .growStyle(GrowType.callout(.semibold), color: tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct JournalPlaceholder: View {
    let kicker: String
    let title: String
    let icon: String
    let note: String

    var body: some View {
        ZStack {
            PaperBackground(light: 0.4)
            VStack(alignment: .leading, spacing: GrowSpacing.md) {
                Text(kicker).fieldLabel().growEntrance(0)
                Text(title).growStyle(GrowType.displayTitle()).growEntrance(1)
                Hairline().growEntrance(2)
                HStack(alignment: .top, spacing: GrowSpacing.md) {
                    ZStack {
                        Circle().fill(GrowPalette.sprout50)
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundStyle(GrowPalette.sprout600)
                    }
                    .frame(width: 52, height: 52)
                    Text(note)
                        .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .growEntrance(3)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GrowSpacing.lg)
            .padding(.top, GrowSpacing.xl)
        }
    }
}

/// Staggered fade + rise entrance for an editorial page-load feel.
private struct GrowEntrance: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                withAnimation(.smooth(duration: 0.55).delay(Double(index) * 0.08)) {
                    shown = true
                }
            }
    }
}

extension View {
    func growEntrance(_ index: Int) -> some View { modifier(GrowEntrance(index: index)) }
}

#Preview {
    let catalog = PlantCatalogService()
    let store = GrowStore(context: GrowModelContainer.shared.mainContext, catalog: catalog)
    let streakService = StreakService(context: GrowModelContainer.shared.mainContext)
    RootView()
        .environment(catalog)
        .environment(store)
        .environment(streakService)
        .environment(PhotoService(context: GrowModelContainer.shared.mainContext, streakService: streakService))
        .environment(NotificationService())
        .environment(WidgetSyncService())
        .environment(ReelRenderingService(context: GrowModelContainer.shared.mainContext))
}

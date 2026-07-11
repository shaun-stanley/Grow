import SwiftUI
import SwiftData

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

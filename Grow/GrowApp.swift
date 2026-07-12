import SwiftUI
import SwiftData

@main
struct GrowApp: App {
    private let modelContainer = GrowModelContainer.shared
    @State private var catalog: PlantCatalogService
    @State private var store: GrowStore
    @State private var streakService: StreakService
    @State private var photoService: PhotoService
    @State private var notificationService: NotificationService
    @State private var widgetSyncService: WidgetSyncService
    @State private var reelRenderingService: ReelRenderingService

    init() {
        let catalog = PlantCatalogService()
        let store = GrowStore(context: modelContainer.mainContext, catalog: catalog)
        let streakService = StreakService(context: modelContainer.mainContext)
        let photoService = PhotoService(context: modelContainer.mainContext, streakService: streakService)
        let notificationService = NotificationService()
        let widgetSyncService = WidgetSyncService()
        let reelRenderingService = ReelRenderingService(context: modelContainer.mainContext)
        _catalog = State(initialValue: catalog)
        _store = State(initialValue: store)
        _streakService = State(initialValue: streakService)
        _photoService = State(initialValue: photoService)
        _notificationService = State(initialValue: notificationService)
        _widgetSyncService = State(initialValue: widgetSyncService)
        _reelRenderingService = State(initialValue: reelRenderingService)

        let launchArguments = CommandLine.arguments
        // Debug-only: seed a grown specimen so the active "spread" can be reviewed.
        if launchArguments.contains("-seedSampleGrow"), store.activeGrows().isEmpty {
            if let grow = try? store.createGrow(speciesID: "basil", nickname: "Genovese Basil", system: .kratky) {
                grow.startDate = Calendar.current.date(byAdding: .day, value: -23, to: Date()) ?? Date()
                grow.currentStage = .flowering
                try? store.save()
            }
        }

        Self.seedFirstWeekIfRequested(
            arguments: launchArguments,
            store: store,
            catalog: catalog,
            photoService: photoService
        )

        if launchArguments.contains("-seedSampleCaptures"),
           let grow = store.activeGrows().first,
           (grow.photos ?? []).isEmpty {
            let species = catalog.species(id: grow.speciesID)
            let startDate = Calendar.current.startOfDay(for: grow.startDate)
            for offset in 0..<8 {
                let captureDate = Calendar.current.date(
                    byAdding: .day,
                    value: offset,
                    to: startDate
                )?.addingTimeInterval(9 * 60 * 60) ?? Date()
                _ = photoService.recordPrototypeCapture(
                    for: grow,
                    species: species,
                    capturedAt: captureDate
                )
            }
        }

        if launchArguments.contains("-renderSampleReel"),
           let grow = store.activeGrows().first,
           !(grow.photos ?? []).isEmpty,
           (grow.reels ?? []).isEmpty {
            let species = catalog.species(id: grow.speciesID)
            Task { @MainActor in
                await reelRenderingService.renderPreview(for: grow, species: species)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalog)
                .environment(store)
                .environment(streakService)
                .environment(photoService)
                .environment(notificationService)
                .environment(widgetSyncService)
                .environment(reelRenderingService)
                .tint(GrowPalette.accent)
        }
        .modelContainer(modelContainer)
    }

    private static func launchValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func seedFirstWeekIfRequested(
        arguments: [String],
        store: GrowStore,
        catalog: PlantCatalogService,
        photoService: PhotoService
    ) {
        #if DEBUG
        guard arguments.contains("-seedFirstWeekGrow") else { return }
        try? store.resetDebugSampleData()

        let targetDay = Int(launchValue(after: "-seedFirstWeekDay", in: arguments) ?? "2") ?? 2
        let clampedDay = min(7, max(1, targetDay))
        let startDate = Calendar.current.date(byAdding: .day, value: -(clampedDay - 1), to: Date()) ?? Date()
        guard let grow = try? store.createGrow(speciesID: "basil", nickname: "First Week Basil", system: .kratky) else {
            return
        }
        grow.startDate = Calendar.current.startOfDay(for: startDate)
        grow.currentStage = .germination

        let species = catalog.species(id: grow.speciesID)
        for dayOffset in 0..<max(0, clampedDay - 1) {
            let captureDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: grow.startDate)?
                .addingTimeInterval(9 * 60 * 60) ?? Date()
            _ = photoService.recordPrototypeCapture(for: grow, species: species, capturedAt: captureDate)
        }
        try? store.save()
        #endif
    }
}

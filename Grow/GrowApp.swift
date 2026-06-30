import SwiftUI
import SwiftData

@main
struct GrowApp: App {
    private let modelContainer = GrowModelContainer.shared
    @State private var catalog: PlantCatalogService
    @State private var store: GrowStore
    @State private var streakService: StreakService
    @State private var photoService: PhotoService

    init() {
        let catalog = PlantCatalogService()
        let store = GrowStore(context: modelContainer.mainContext, catalog: catalog)
        let streakService = StreakService(context: modelContainer.mainContext)
        let photoService = PhotoService(context: modelContainer.mainContext, streakService: streakService)
        _catalog = State(initialValue: catalog)
        _store = State(initialValue: store)
        _streakService = State(initialValue: streakService)
        _photoService = State(initialValue: photoService)

        // Debug-only: seed a grown specimen so the active "spread" can be reviewed.
        if CommandLine.arguments.contains("-seedSampleGrow"), store.activeGrows().isEmpty {
            let grow = store.createGrow(speciesID: "basil", nickname: "Genovese Basil", system: .kratky)
            grow.startDate = Calendar.current.date(byAdding: .day, value: -23, to: Date()) ?? Date()
            grow.currentStage = .flowering
            store.save()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalog)
                .environment(store)
                .environment(streakService)
                .environment(photoService)
                .tint(GrowPalette.accent)
        }
        .modelContainer(modelContainer)
    }
}

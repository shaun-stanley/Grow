import Foundation
import SwiftData
import Observation

/// The aggregate repository over SwiftData — create/fetch/archive grows and seed their
/// care tasks. Owns the main `ModelContext`. Injected into the view tree via `.environment`.
@Observable
final class GrowStore {
    private let context: ModelContext
    private let catalog: PlantCatalogService

    init(context: ModelContext, catalog: PlantCatalogService) {
        self.context = context
        self.catalog = catalog
    }

    // MARK: Fetch

    func activeGrows() -> [Grow] {
        let descriptor = FetchDescriptor<Grow>(
            predicate: #Predicate { $0.isActive && $0.archivedDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func allGrows() -> [Grow] {
        let descriptor = FetchDescriptor<Grow>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    var hasAnyGrow: Bool { !allGrows().isEmpty }

    // MARK: Mutate

    /// Create a new grow and seed its care tasks from the species' templates.
    @discardableResult
    func createGrow(speciesID: String, nickname: String, system: GrowSystem) -> Grow {
        let grow = Grow(nickname: nickname, speciesID: speciesID, system: system)
        context.insert(grow)

        if let species = catalog.species(id: speciesID) {
            let now = Date()
            for template in species.careTemplates {
                let task = CareTask(kind: template.kind)
                task.nextDueDate = Calendar.current.date(byAdding: .day, value: template.everyNDays, to: now)
                task.grow = grow
                context.insert(task)
            }
        }
        save()
        return grow
    }

    func archive(_ grow: Grow) {
        grow.isActive = false
        grow.archivedDate = Date()
        save()
    }

    func save() {
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("⚠️ Grow: save failed: \(error)")
            #endif
        }
    }
}

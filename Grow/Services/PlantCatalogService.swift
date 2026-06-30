import Foundation
import Observation

/// Loads the bundled plant-care knowledge base. Works fully offline; a remote-override
/// fetch can be layered on later (load bundled JSON first, swap in a newer version if
/// `remoteCatalogVersion > bundledVersion`).
@Observable
final class PlantCatalogService {
    private(set) var species: [PlantSpecies] = []
    private(set) var catalogVersion: Int = 0

    init() {
        load()
    }

    func load() {
        guard let url = Bundle.main.url(forResource: "PlantCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("⚠️ Grow: PlantCatalog.json not found in bundle.")
            #endif
            return
        }
        do {
            let catalog = try JSONDecoder().decode(PlantCatalog.self, from: data)
            self.species = catalog.species
            self.catalogVersion = catalog.catalogVersion
        } catch {
            #if DEBUG
            print("⚠️ Grow: failed to decode PlantCatalog.json: \(error)")
            #endif
        }
    }

    func species(id: String) -> PlantSpecies? {
        species.first { $0.id == id }
    }

    /// Beginner-friendly picks surfaced first in onboarding.
    var beginnerPicks: [PlantSpecies] {
        species.filter { $0.difficulty == .easy }
    }
}

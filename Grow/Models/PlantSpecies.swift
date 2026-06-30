import Foundation

/// Read-only care knowledge for a crop. Shipped as bundled JSON (identical for every user),
/// so it is a plain `Codable` value — NOT a CloudKit-synced `@Model`.
struct PlantSpecies: Codable, Identifiable, Hashable {
    let id: String            // stable key, e.g. "basil"
    let commonName: String
    let latinName: String
    let category: Category
    let difficulty: Difficulty
    let lightHoursMin: Int
    let lightHoursMax: Int
    let phMin: Double
    let phMax: Double
    let ecMin: Double
    let ecMax: Double
    let daysToHarvestMin: Int
    let daysToHarvestMax: Int
    let recommendedSystems: [GrowSystem]
    let commonIssues: [String]
    let careTips: [String]
    let careTemplates: [CareTemplate]
    let rarity: Rarity
    let emoji: String

    enum Category: String, Codable, CaseIterable { case herb, leafyGreen, fruiting, root, flower }
    enum Difficulty: String, Codable { case easy, medium, advanced }
    enum Rarity: String, Codable { case common, uncommon, rare, legendary }

    /// A default care task to seed when a grow of this species is created.
    struct CareTemplate: Codable, Hashable {
        let kind: CareKind
        let everyNDays: Int
    }

    var phRangeText: String { String(format: "%.1f–%.1f", phMin, phMax) }
    var harvestText: String { "\(daysToHarvestMin)–\(daysToHarvestMax) days" }
}

/// Bundle of all species, with a version stamp for the future remote-override seam.
struct PlantCatalog: Codable {
    let catalogVersion: Int
    let species: [PlantSpecies]
}

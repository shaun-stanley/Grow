import SwiftUI

/// Hydroponic system types a beginner might use.
enum GrowSystem: String, CaseIterable, Codable, Identifiable {
    case kratky, dwc, nft, wick, ebbFlow, aeroponic, other
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kratky: "Kratky (no pump)"
        case .dwc: "Deep Water Culture"
        case .nft: "Nutrient Film (NFT)"
        case .wick: "Wick"
        case .ebbFlow: "Ebb & Flow"
        case .aeroponic: "Aeroponic"
        case .other: "Other / not sure"
        }
    }

    var shortName: String {
        switch self {
        case .kratky: "Kratky"
        case .dwc: "DWC"
        case .nft: "NFT"
        case .wick: "Wick"
        case .ebbFlow: "Ebb & Flow"
        case .aeroponic: "Aero"
        case .other: "—"
        }
    }
}

/// Growth stages, ordered. Drives the living twin and the timeline.
enum GrowStage: String, CaseIterable, Codable, Comparable {
    case germination, seedling, vegetative, flowering, fruiting, harvest, finished

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: GrowStage, rhs: GrowStage) -> Bool { lhs.order < rhs.order }

    var displayName: String {
        switch self {
        case .germination: "Germinating"
        case .seedling: "Seedling"
        case .vegetative: "Growing"
        case .flowering: "Flowering"
        case .fruiting: "Fruiting"
        case .harvest: "Ready to harvest"
        case .finished: "Harvested"
        }
    }

    var systemImage: String {
        switch self {
        case .germination: "circle.dotted"
        case .seedling: "leaf"
        case .vegetative: "leaf.fill"
        case .flowering: "camera.macro"
        case .fruiting: "applelogo"
        case .harvest: "basket.fill"
        case .finished: "checkmark.seal.fill"
        }
    }

    /// 0…1 visual growth used to draw the living specimen.
    var growthProgress: Double {
        switch self {
        case .germination: 0.08
        case .seedling: 0.24
        case .vegetative: 0.5
        case .flowering: 0.72
        case .fruiting: 0.9
        case .harvest, .finished: 1.0
        }
    }

    /// True once the plant flowers/fruits — the specimen sprouts a bloom.
    var hasBloom: Bool { self >= .flowering && self != .finished }
}

/// A unit of care the plant needs on a cadence.
enum CareKind: String, CaseIterable, Codable, Identifiable {
    case water, nutrientDose, phCheck, ecCheck, topUp, lightAdjust, prune, transplant, custom
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water: "Water"
        case .nutrientDose: "Add nutrients"
        case .phCheck: "Check pH"
        case .ecCheck: "Check EC"
        case .topUp: "Top up water"
        case .lightAdjust: "Adjust light"
        case .prune: "Prune"
        case .transplant: "Transplant"
        case .custom: "Care task"
        }
    }

    var systemImage: String {
        switch self {
        case .water: "drop.fill"
        case .nutrientDose: "flask.fill"
        case .phCheck: "testtube.2"
        case .ecCheck: "bolt.fill"
        case .topUp: "drop.degreesign"
        case .lightAdjust: "lightbulb.fill"
        case .prune: "scissors"
        case .transplant: "arrow.up.bin.fill"
        case .custom: "checklist"
        }
    }
}

/// Numeric environment metrics a grower can log.
enum ReadingMetric: String, CaseIterable, Codable, Identifiable {
    case ph, ec, ppm, tds, waterTempC, airTempC, humidity
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ph: "pH"
        case .ec: "EC"
        case .ppm: "PPM"
        case .tds: "TDS"
        case .waterTempC: "Water temp"
        case .airTempC: "Air temp"
        case .humidity: "Humidity"
        }
    }

    var unit: String {
        switch self {
        case .ph: ""
        case .ec: "mS/cm"
        case .ppm, .tds: "ppm"
        case .waterTempC, .airTempC: "°C"
        case .humidity: "%"
        }
    }
}

/// How Sprout (and the user's real plant) is feeling — drives the twin + mascot.
enum PlantMood: String, Codable {
    case happy, thirsty, hungry, needsCare, sleepy, celebrating

    var color: Color {
        switch self {
        case .happy, .celebrating: GrowPalette.healthy
        case .thirsty: GrowPalette.info
        case .hungry, .needsCare: GrowPalette.needsCare
        case .sleepy: GrowPalette.textSecondary
        }
    }
}

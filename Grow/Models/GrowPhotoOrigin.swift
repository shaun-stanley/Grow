import Foundation

enum GrowPhotoOrigin: String, Codable, Sendable {
    case legacyUserMedia
    case camera
    case photoLibrary
    case demoSample
}

enum GrowPhotoProvenance: Equatable, Sendable {
    case legacyUserMedia
    case camera
    case photoLibrary
    case demoSample(sampleID: String)
    case recoverySample(sampleID: String)
    case neutralFallback
}

enum GrowPhotoQuality: Equatable, Sendable {
    case fullSize
    case thumbnail
    case fallback
}

enum GrowPhotoOrdering {
    static func areInIncreasingOrder(_ lhs: GrowPhoto, _ rhs: GrowPhoto) -> Bool {
        if lhs.dayIndex != rhs.dayIndex {
            return lhs.dayIndex < rhs.dayIndex
        }
        if lhs.capturedAt != rhs.capturedAt {
            return lhs.capturedAt < rhs.capturedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

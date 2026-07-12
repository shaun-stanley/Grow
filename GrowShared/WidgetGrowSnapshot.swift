import Foundation

enum WidgetSnapshotKeys {
    static let suiteName = "group.com.sviftstudios.Grow"
    static let activeGrowSnapshot = "widget.activeGrowSnapshot"
    static let activeGrowID = "widget.activeGrowID"
    static let validationStamp = "widget.validationStamp"
}

struct WidgetGrowSnapshot: Codable, Equatable {
    let schemaVersion: Int
    let generatedAt: Date
    let activeGrowID: UUID
    let speciesID: String
    let displayName: String
    let latinName: String?
    let emoji: String?
    let systemName: String
    let stageRaw: String
    let stageDisplayName: String
    let stageSystemImage: String
    let dayCount: Int
    let frameCount: Int
    let targetFrameCount: Int
    let futureReelProgress: Double
    let modeledProgress: Double
    let streakCurrent: Int
    let streakLongest: Int
    let streakMilestoneCopy: String
    let nextCaptureTitle: String
    let nextCaptureBody: String
    let latestPhotoFileName: String?
    let latestCapturedAt: Date?

    static let sample = WidgetGrowSnapshot(
        schemaVersion: 1,
        generatedAt: Date(timeIntervalSince1970: 1_752_307_200),
        activeGrowID: UUID(uuidString: "A4BBE6BA-D7C5-4B45-B9A5-B03345039588")!,
        speciesID: "basil",
        displayName: "Basil",
        latinName: "Ocimum basilicum",
        emoji: "🌿",
        systemName: "Kratky",
        stageRaw: "seedling",
        stageDisplayName: "Seedling",
        stageSystemImage: "leaf.fill",
        dayCount: 7,
        frameCount: 7,
        targetFrameCount: 30,
        futureReelProgress: 7.0 / 30.0,
        modeledProgress: 0.28,
        streakCurrent: 7,
        streakLongest: 7,
        streakMilestoneCopy: "7 days to Day 14",
        nextCaptureTitle: "First-week frame",
        nextCaptureBody: "Quiet daily frames are building the first reveal.",
        latestPhotoFileName: "Photos/sample/day-7.jpg",
        latestCapturedAt: Date(timeIntervalSince1970: 1_752_307_200)
    )

    static let empty = WidgetGrowSnapshot(
        schemaVersion: 1,
        generatedAt: Date(timeIntervalSince1970: 1_752_307_200),
        activeGrowID: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        speciesID: "",
        displayName: "Start your first grow",
        latinName: nil,
        emoji: "🌱",
        systemName: "",
        stageRaw: "germination",
        stageDisplayName: "Waiting",
        stageSystemImage: "leaf",
        dayCount: 0,
        frameCount: 0,
        targetFrameCount: 30,
        futureReelProgress: 0,
        modeledProgress: 0.06,
        streakCurrent: 0,
        streakLongest: 0,
        streakMilestoneCopy: "Plant a seed to begin",
        nextCaptureTitle: "Start the reel",
        nextCaptureBody: "One steady photo gives the whole grow a beginning.",
        latestPhotoFileName: nil,
        latestCapturedAt: nil
    )
}

struct WidgetSnapshotReader {
    let defaults: UserDefaults
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: WidgetSnapshotKeys.suiteName)
            ?? .standard
    }

    func read() -> WidgetGrowSnapshot? {
        guard let data = defaults.data(forKey: WidgetSnapshotKeys.activeGrowSnapshot) else {
            return nil
        }
        return try? decoder.decode(WidgetGrowSnapshot.self, from: data)
    }
}

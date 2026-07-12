import Foundation
import SwiftData

// MARK: - Grow (the primary aggregate: one growing plant instance)

@Model
final class Grow {
    var id: UUID = UUID()
    var nickname: String = ""
    /// Soft FK into the bundled PlantSpecies catalog (string key, not a SwiftData relationship).
    var speciesID: String = ""
    var systemTypeRaw: String = GrowSystem.kratky.rawValue
    var startDate: Date = Date()
    var archivedDate: Date?
    var harvestedDate: Date?
    var currentStageRaw: String = GrowStage.germination.rawValue
    var isActive: Bool = true
    var coverPhotoID: UUID?
    var notes: String = ""
    var iconName: String = "leaf.fill"

    @Relationship(deleteRule: .cascade, inverse: \GrowPhoto.grow)
    var photos: [GrowPhoto]? = []
    @Relationship(deleteRule: .cascade, inverse: \CareTask.grow)
    var careTasks: [CareTask]? = []
    @Relationship(deleteRule: .cascade, inverse: \CareLog.grow)
    var careLogs: [CareLog]? = []
    @Relationship(deleteRule: .cascade, inverse: \Reading.grow)
    var readings: [Reading]? = []
    @Relationship(deleteRule: .cascade, inverse: \Reel.grow)
    var reels: [Reel]? = []
    @Relationship(deleteRule: .cascade, inverse: \Diagnosis.grow)
    var diagnoses: [Diagnosis]? = []

    init(nickname: String = "", speciesID: String = "", system: GrowSystem = .kratky, startDate: Date = Date()) {
        self.nickname = nickname
        self.speciesID = speciesID
        self.systemTypeRaw = system.rawValue
        self.startDate = startDate
    }

    var system: GrowSystem {
        get { GrowSystem(rawValue: systemTypeRaw) ?? .other }
        set { systemTypeRaw = newValue.rawValue }
    }

    var currentStage: GrowStage {
        get { GrowStage(rawValue: currentStageRaw) ?? .germination }
        set { currentStageRaw = newValue.rawValue }
    }

    /// 1-based day count since the grow started (Day 1 == start date).
    var dayCount: Int {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return max(1, days + 1)
    }
}

// MARK: - GrowPhoto (one daily photo)

@Model
final class GrowPhoto {
    var id: UUID = UUID()
    var capturedAt: Date = Date()
    var stageRaw: String = GrowStage.germination.rawValue
    /// Filename inside the App Group container (Photos/{growID}/{id}.heic) — NOT the bytes.
    var localFileName: String = ""
    /// Small JPEG kept out-of-row but synced, so grids/widgets show something fast.
    @Attribute(.externalStorage) var thumbnailData: Data?
    /// Day index relative to the grow's start (1-based).
    var dayIndex: Int = 1
    /// Capture-time alignment payload, JSON-encoded (transform to normalize against the prior frame).
    var alignmentData: Data?
    var caption: String = ""
    var isMilestone: Bool = false
    var originRaw: String = GrowPhotoOrigin.legacyUserMedia.rawValue
    var sourceSampleID: String?

    var grow: Grow?

    init(capturedAt: Date = Date(), dayIndex: Int = 1, stage: GrowStage = .germination) {
        self.capturedAt = capturedAt
        self.dayIndex = dayIndex
        self.stageRaw = stage.rawValue
    }

    var stage: GrowStage {
        get { GrowStage(rawValue: stageRaw) ?? .germination }
        set { stageRaw = newValue.rawValue }
    }

    var origin: GrowPhotoOrigin {
        get { GrowPhotoOrigin(rawValue: originRaw) ?? .legacyUserMedia }
        set { originRaw = newValue.rawValue }
    }
}

// MARK: - CareTask (a recurring care obligation)

@Model
final class CareTask {
    var id: UUID = UUID()
    var kindRaw: String = CareKind.water.rawValue
    var title: String = ""
    /// Cadence, JSON-encoded: { everyNDays, preferredTimeMinutes }.
    var cadenceData: Data?
    var nextDueDate: Date?
    var lastCompletedDate: Date?
    var isEnabled: Bool = true
    var defaultDoseML: Double?

    var grow: Grow?

    init(kind: CareKind = .water, title: String = "", nextDueDate: Date? = nil) {
        self.kindRaw = kind.rawValue
        self.title = title.isEmpty ? kind.displayName : title
        self.nextDueDate = nextDueDate
    }

    var kind: CareKind {
        get { CareKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }

    var isDue: Bool {
        guard isEnabled, let due = nextDueDate else { return false }
        return due <= Date()
    }
}

// MARK: - CareLog (an immutable record that care happened)

@Model
final class CareLog {
    var id: UUID = UUID()
    var performedAt: Date = Date()
    var kindRaw: String = CareKind.water.rawValue
    /// Which CareTask this satisfied, if any (soft ref).
    var taskID: UUID?
    var valueDouble: Double?
    var unit: String?
    var note: String = ""

    var grow: Grow?

    init(kind: CareKind = .water, performedAt: Date = Date()) {
        self.kindRaw = kind.rawValue
        self.performedAt = performedAt
    }

    var kind: CareKind {
        get { CareKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }
}

// MARK: - Reading (optional numeric environment log)

@Model
final class Reading {
    var id: UUID = UUID()
    var takenAt: Date = Date()
    var metricRaw: String = ReadingMetric.ph.rawValue
    var value: Double = 0

    var grow: Grow?

    init(metric: ReadingMetric = .ph, value: Double = 0, takenAt: Date = Date()) {
        self.metricRaw = metric.rawValue
        self.value = value
        self.takenAt = takenAt
    }

    var metric: ReadingMetric {
        get { ReadingMetric(rawValue: metricRaw) ?? .ph }
        set { metricRaw = newValue.rawValue }
    }
}

// MARK: - Reel (a rendered time-lapse video)

@Model
final class Reel {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    /// .mov/.mp4 filename in the App Group container — never the bytes.
    var localFileName: String = ""
    @Attribute(.externalStorage) var posterFrameData: Data?
    var sourcePhotoStart: Date = Date()
    var sourcePhotoEnd: Date = Date()
    var photoCount: Int = 0
    var durationSeconds: Double = 0
    var musicTrackID: String?
    var styleRaw: String = "classic"
    var shareCount: Int = 0
    var remotePublicID: String?

    var grow: Grow?

    init(createdAt: Date = Date()) {
        self.createdAt = createdAt
    }
}

// MARK: - Diagnosis (an AI Plant Doctor result — a per-plant health journal)

@Model
final class Diagnosis {
    var id: UUID = UUID()
    var requestedAt: Date = Date()
    var sourcePhotoID: UUID?
    var summary: String = ""
    var confidence: Double = 0
    var categoryRaw: String = "healthy"
    /// JSON-encoded array of diagnosed issues + fixes.
    var issuesData: Data?
    var modelVersion: String = ""

    var grow: Grow?

    init(requestedAt: Date = Date(), summary: String = "", confidence: Double = 0) {
        self.requestedAt = requestedAt
        self.summary = summary
        self.confidence = confidence
    }
}

// MARK: - StreakState (per-user; one row) — Anchor's forgiving streak model

@Model
final class StreakState {
    var id: UUID = UUID()
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastCareDate: Date?
    var freezeTokensRemaining: Int = 2

    init() {}
}

// MARK: - Achievement (badges + the collectible plant "dex")

@Model
final class Achievement {
    var id: UUID = UUID()
    /// Stable key, e.g. "first_harvest", "dex_basil".
    var identifier: String = ""
    var unlockedAt: Date?
    var progress: Double = 0
    /// milestone | dexSpecies | streak | social
    var kindRaw: String = "milestone"

    init(identifier: String = "", kindRaw: String = "milestone") {
        self.identifier = identifier
        self.kindRaw = kindRaw
    }

    var isUnlocked: Bool { unlockedAt != nil }
}

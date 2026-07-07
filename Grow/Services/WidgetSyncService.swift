import Foundation
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

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
}

struct WidgetSyncValidation: Equatable {
    let checkedAt: Date
    let isUsingAppGroupContainer: Bool
    let canWriteDefaults: Bool
    let canWriteFiles: Bool
    let message: String

    var isHealthy: Bool {
        isUsingAppGroupContainer && canWriteDefaults && canWriteFiles
    }
}

@MainActor
@Observable
final class WidgetSyncService {
    private enum Keys {
        static let activeGrowSnapshot = "widget.activeGrowSnapshot"
        static let activeGrowID = "widget.activeGrowID"
        static let validationStamp = "widget.validationStamp"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager

    var latestSnapshot: WidgetGrowSnapshot?
    var latestValidation: WidgetSyncValidation?

    init(defaults: UserDefaults? = nil, fileManager: FileManager = .default) {
        self.defaults = defaults ?? AppGroup.defaults
        self.fileManager = fileManager
        latestSnapshot = readActiveGrowSnapshot()
    }

    @discardableResult
    func validateSharedStorage() -> WidgetSyncValidation {
        let checkedAt = Date()
        let defaultsValue = checkedAt.timeIntervalSince1970
        defaults.set(defaultsValue, forKey: Keys.validationStamp)
        let canWriteDefaults = defaults.double(forKey: Keys.validationStamp) == defaultsValue

        let validationDirectory = AppGroup.containerURL.appendingPathComponent("Widget", isDirectory: true)
        let validationFile = validationDirectory.appendingPathComponent("validation.txt")
        var canWriteFiles = false

        do {
            try fileManager.createDirectory(at: validationDirectory, withIntermediateDirectories: true)
            try Data("ok".utf8).write(to: validationFile, options: [.atomic])
            canWriteFiles = fileManager.fileExists(atPath: validationFile.path)
            try? fileManager.removeItem(at: validationFile)
        } catch {
            canWriteFiles = false
        }

        let isUsingAppGroupContainer = AppGroup.sharedContainerURL != nil
        let validation = WidgetSyncValidation(
            checkedAt: checkedAt,
            isUsingAppGroupContainer: isUsingAppGroupContainer,
            canWriteDefaults: canWriteDefaults,
            canWriteFiles: canWriteFiles,
            message: validationMessage(
                isUsingAppGroupContainer: isUsingAppGroupContainer,
                canWriteDefaults: canWriteDefaults,
                canWriteFiles: canWriteFiles
            )
        )
        latestValidation = validation
        return validation
    }

    func sync(activeGrow grow: Grow?, species: PlantSpecies?, streak: StreakUpdate) {
        guard let grow else {
            clearActiveGrow()
            return
        }

        let validation = validateSharedStorage()
        let snapshot = makeSnapshot(grow: grow, species: species, streak: streak)

        do {
            let data = try encoder.encode(snapshot)
            defaults.set(data, forKey: Keys.activeGrowSnapshot)
            defaults.set(snapshot.activeGrowID.uuidString, forKey: Keys.activeGrowID)
            latestSnapshot = snapshot
            reloadWidgetTimelines()
        } catch {
            #if DEBUG
            print("Grow: widget sync encode failed: \(error)")
            #endif
        }

        #if DEBUG
        if !validation.isHealthy {
            print("Grow: widget sync validation: \(validation.message)")
        }
        #endif
    }

    func clearActiveGrow() {
        defaults.removeObject(forKey: Keys.activeGrowSnapshot)
        defaults.removeObject(forKey: Keys.activeGrowID)
        latestSnapshot = nil
        reloadWidgetTimelines()
    }

    func readActiveGrowSnapshot() -> WidgetGrowSnapshot? {
        guard let data = defaults.data(forKey: Keys.activeGrowSnapshot) else { return nil }
        return try? decoder.decode(WidgetGrowSnapshot.self, from: data)
    }

    private func makeSnapshot(grow: Grow, species: PlantSpecies?, streak: StreakUpdate) -> WidgetGrowSnapshot {
        let photos = (grow.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }
        let latestPhoto = photos.last
        let dayIndex = max(1, latestPhoto?.dayIndex ?? grow.dayCount)
        let modeledProgress = ModeledGrowthCurve.progress(dayIndex: dayIndex, species: species)
        let stage = ModeledGrowthCurve.stage(for: modeledProgress)
        let frameCount = photos.count

        return WidgetGrowSnapshot(
            schemaVersion: 1,
            generatedAt: Date(),
            activeGrowID: grow.id,
            speciesID: grow.speciesID,
            displayName: grow.nickname.isEmpty ? (species?.commonName ?? "My plant") : grow.nickname,
            latinName: species?.latinName,
            emoji: species?.emoji,
            systemName: grow.system.shortName,
            stageRaw: stage.rawValue,
            stageDisplayName: stage.displayName,
            stageSystemImage: stage.systemImage,
            dayCount: grow.dayCount,
            frameCount: frameCount,
            targetFrameCount: 30,
            futureReelProgress: min(1, Double(frameCount) / 30),
            modeledProgress: modeledProgress,
            streakCurrent: streak.current,
            streakLongest: streak.longest,
            streakMilestoneCopy: streak.milestoneCopy,
            nextCaptureTitle: captureTitle(dayCount: grow.dayCount, frameCount: frameCount),
            nextCaptureBody: captureBody(dayCount: grow.dayCount, frameCount: frameCount),
            latestPhotoFileName: latestPhoto?.localFileName.isEmpty == false ? latestPhoto?.localFileName : nil,
            latestCapturedAt: latestPhoto?.capturedAt
        )
    }

    private func captureTitle(dayCount: Int, frameCount: Int) -> String {
        if frameCount == 0 { return "Start the reel" }
        return dayCount <= 7 ? "First-week frame" : "Today's frame"
    }

    private func captureBody(dayCount: Int, frameCount: Int) -> String {
        if frameCount == 0 {
            return "One steady photo gives the whole grow a beginning."
        }

        switch dayCount {
        case 1...2:
            return "No visible change is normal. The before-frame is doing real work."
        case 3...7:
            return "Quiet daily frames are building the first reveal."
        default:
            return "Keep the angle steady and add the next reel frame."
        }
    }

    private func validationMessage(isUsingAppGroupContainer: Bool, canWriteDefaults: Bool, canWriteFiles: Bool) -> String {
        if isUsingAppGroupContainer && canWriteDefaults && canWriteFiles {
            return "App Group storage is writable."
        }
        if !isUsingAppGroupContainer {
            return "App Group container is unavailable; Grow is using fallback storage."
        }
        if !canWriteDefaults {
            return "App Group defaults are not writable."
        }
        return "App Group files are not writable."
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

import Foundation
import Observation
import SwiftData

struct CaptureAlignment: Codable, Equatable {
    let score: Double
    let xOffset: Double
    let yOffset: Double
    let rotationDegrees: Double

    var percent: Int { Int((score * 100).rounded()) }

    var adjective: String {
        switch score {
        case 0.97...: "buttery"
        case 0.93...: "steady"
        case 0.88...: "close"
        default: "needs a nudge"
        }
    }
}

struct CaptureReward: Identifiable, Equatable {
    let id = UUID()
    let photoID: UUID
    let capturedAt: Date
    let dayIndex: Int
    let frameCount: Int
    let targetFrameCount: Int
    let alignment: CaptureAlignment
    let modeledProgressBefore: Double
    let modeledProgressAfter: Double
    let expectedStage: GrowStage
    let streak: StreakUpdate

    var futureReelProgress: Double {
        min(1, Double(frameCount) / Double(targetFrameCount))
    }

    var dayTitle: String { "Day \(dayIndex)" }

    var milestoneTitle: String? {
        switch dayIndex {
        case 1: "Your reel starts here"
        case 3: "First streak milestone"
        case 5: "Ahead of the curve"
        case 7: "First week recap unlocked"
        default: nil
        }
    }
}

@Observable
final class PhotoService {
    private let context: ModelContext
    private let streakService: StreakService
    private let encoder = JSONEncoder()
    private let calendar: Calendar

    init(context: ModelContext, streakService: StreakService, calendar: Calendar = .current) {
        self.context = context
        self.streakService = streakService
        self.calendar = calendar
    }

    /// Prototype capture used until the AVFoundation camera lands. It records durable
    /// photo metadata, alignment JSON, streak progress, and the exact reward payload the
    /// real camera flow will emit.
    @discardableResult
    func recordPrototypeCapture(for grow: Grow, species: PlantSpecies?) -> CaptureReward {
        let existingPhotos = grow.photos ?? []
        let frameCount = existingPhotos.count + 1
        let capturedAt = Date()
        let dayIndex = max(growDayIndex(for: grow, at: capturedAt), frameCount)
        let progressBefore = ModeledGrowthCurve.progress(dayIndex: max(1, dayIndex - 1), species: species)
        let progressAfter = ModeledGrowthCurve.progress(dayIndex: dayIndex, species: species)
        let stage = ModeledGrowthCurve.stage(for: progressAfter)
        let alignment = prototypeAlignment(frameCount: frameCount)

        let photo = GrowPhoto(capturedAt: capturedAt, dayIndex: dayIndex, stage: stage)
        photo.alignmentData = try? encoder.encode(alignment)
        photo.caption = rewardCaption(dayIndex: dayIndex, alignment: alignment)
        photo.isMilestone = CaptureReward(
            photoID: photo.id,
            capturedAt: capturedAt,
            dayIndex: dayIndex,
            frameCount: frameCount,
            targetFrameCount: 30,
            alignment: alignment,
            modeledProgressBefore: progressBefore,
            modeledProgressAfter: progressAfter,
            expectedStage: stage,
            streak: streakService.snapshot()
        ).milestoneTitle != nil
        photo.grow = grow
        context.insert(photo)

        if grow.coverPhotoID == nil {
            grow.coverPhotoID = photo.id
        }
        grow.currentStage = stage

        let streak = streakService.recordCapture(at: capturedAt)
        save()

        return CaptureReward(
            photoID: photo.id,
            capturedAt: capturedAt,
            dayIndex: dayIndex,
            frameCount: frameCount,
            targetFrameCount: 30,
            alignment: alignment,
            modeledProgressBefore: progressBefore,
            modeledProgressAfter: progressAfter,
            expectedStage: stage,
            streak: streak
        )
    }

    private func growDayIndex(for grow: Grow, at date: Date) -> Int {
        let start = calendar.startOfDay(for: grow.startDate)
        let capture = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: capture).day ?? 0
        return max(1, days + 1)
    }

    private func prototypeAlignment(frameCount: Int) -> CaptureAlignment {
        let cycle = Double((frameCount * 7) % 12)
        let score = min(0.99, 0.88 + cycle / 100)
        return CaptureAlignment(
            score: score,
            xOffset: Double((frameCount % 5) - 2) * 0.012,
            yOffset: Double(((frameCount + 2) % 5) - 2) * 0.01,
            rotationDegrees: Double((frameCount % 7) - 3) * 0.15
        )
    }

    private func rewardCaption(dayIndex: Int, alignment: CaptureAlignment) -> String {
        "\(alignment.percent)% aligned - \(alignment.adjective) Day \(dayIndex) frame"
    }

    private func save() {
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Grow: photo save failed: \(error)")
            #endif
        }
    }
}

enum ModeledGrowthCurve {
    static func progress(dayIndex: Int, species: PlantSpecies?) -> Double {
        let harvestDay = max(21, species?.daysToHarvestMin ?? 35)
        let raw = Double(max(1, dayIndex)) / Double(harvestDay)
        let eased = 1 - pow(1 - min(1, raw), 2.2)
        return min(0.98, max(0.06, eased))
    }

    static func stage(for progress: Double) -> GrowStage {
        switch progress {
        case ..<0.18: .germination
        case ..<0.35: .seedling
        case ..<0.68: .vegetative
        case ..<0.82: .flowering
        case ..<0.96: .fruiting
        default: .harvest
        }
    }
}

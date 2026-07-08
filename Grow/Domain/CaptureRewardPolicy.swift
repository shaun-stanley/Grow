import SwiftUI

enum CaptureRewardPolicy {
    struct MicroMoment: Equatable {
        let title: String
        let body: String
        let icon: String
        let tintRole: TintRole
    }

    enum TintRole: String, Equatable {
        case bloom
        case info
        case sprout
        case healthy
    }

    static func milestoneTitle(dayIndex: Int) -> String? {
        switch dayIndex {
        case 1: "Your reel starts here"
        case 3: "First streak milestone"
        case 5: "Ahead of the curve"
        case 7: "First week recap unlocked"
        default: nil
        }
    }

    static func firstWeekNote(dayIndex: Int) -> String? {
        switch dayIndex {
        case 1:
            "The first frame matters because it gives every future leaf a real before."
        case 2:
            "No visible change is normal. The reel is already getting steadier."
        case 3...6:
            "Quiet growth counts. Keep the angle steady and the reveal will do the talking."
        case 7:
            "One week of frames is enough to start seeing the story."
        default:
            nil
        }
    }

    static func futureReelProgress(frameCount: Int, targetFrameCount: Int) -> Double {
        guard targetFrameCount > 0 else { return 1 }
        return min(1, max(0, Double(frameCount) / Double(targetFrameCount)))
    }

    static func caption(dayIndex: Int, alignment: CaptureAlignment) -> String {
        "\(alignment.percent)% aligned - \(alignment.adjective). \(alignment.sourceLabel) for Day \(dayIndex)."
    }

    static func microMoment(for reward: CaptureReward) -> MicroMoment {
        switch reward.dayIndex {
        case 1:
            MicroMoment(
                title: "Reel seed planted",
                body: "The before-frame is now anchored. Every future leaf has somewhere to return to.",
                icon: "record.circle",
                tintRole: .bloom
            )
        case 2:
            MicroMoment(
                title: "Germination is mostly invisible",
                body: "Today is about roots, moisture, and patience. The twin moves so the habit has a pulse.",
                icon: "water.waves",
                tintRole: .info
            )
        case 3:
            MicroMoment(
                title: "First streak marker",
                body: "Three steady frames is the first real signal that this grow has a rhythm.",
                icon: "flame.fill",
                tintRole: .bloom
            )
        case 5:
            MicroMoment(
                title: "Ahead of the average beginner",
                body: "Most first grows lose consistency here. Five frames means your recap already has structure.",
                icon: "chart.line.uptrend.xyaxis",
                tintRole: .sprout
            )
        case 7:
            MicroMoment(
                title: "First-week recap ready",
                body: "Seven frames is enough to make the quiet first week feel like a story.",
                icon: "film.stack.fill",
                tintRole: .bloom
            )
        default:
            if reward.alignment.score >= 0.96 && reward.alignment.source == .visionTranslation {
                MicroMoment(
                    title: "Frame locked",
                    body: "That match will make the future time-lapse feel calmer and more cinematic.",
                    icon: "scope",
                    tintRole: .sprout
                )
            } else {
                MicroMoment(
                    title: "Memory banked",
                    body: "Even imperfect frames count. The reel gets stronger because the day was captured.",
                    icon: "checkmark.seal.fill",
                    tintRole: .healthy
                )
            }
        }
    }
}

extension CaptureRewardPolicy.TintRole {
    var color: Color {
        switch self {
        case .bloom: GrowPalette.bloom
        case .info: GrowPalette.info
        case .sprout: GrowPalette.sprout600
        case .healthy: GrowPalette.healthy
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

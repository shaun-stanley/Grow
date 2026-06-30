import Foundation
import Observation
import SwiftData

struct StreakUpdate: Equatable {
    let current: Int
    let longest: Int
    let freezeTokensRemaining: Int
    let didAdvance: Bool
    let spentFreezeToken: Bool

    var nextMilestone: Int {
        [3, 7, 14, 30, 60, 100].first { $0 > current } ?? (((current / 50) + 1) * 50)
    }

    var milestoneProgress: Double {
        guard nextMilestone > 0 else { return 1 }
        return min(1, Double(current) / Double(nextMilestone))
    }

    var milestoneCopy: String {
        let remaining = max(0, nextMilestone - current)
        return remaining == 0 ? "Milestone reached" : "\(remaining) days to Day \(nextMilestone)"
    }
}

@Observable
final class StreakService {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func snapshot() -> StreakUpdate {
        let state = streakState()
        return StreakUpdate(
            current: state.currentStreak,
            longest: state.longestStreak,
            freezeTokensRemaining: state.freezeTokensRemaining,
            didAdvance: false,
            spentFreezeToken: false
        )
    }

    @discardableResult
    func recordCapture(at date: Date = Date()) -> StreakUpdate {
        let state = streakState()
        let previous = state.currentStreak
        let previousFreezeTokens = state.freezeTokensRemaining
        var spentFreezeToken = false

        if let lastDate = state.lastCareDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let captureDay = calendar.startOfDay(for: date)
            let daysElapsed = calendar.dateComponents([.day], from: lastDay, to: captureDay).day ?? 0

            if daysElapsed == 1 {
                state.currentStreak += 1
                state.lastCareDate = date
            } else if daysElapsed > 1 {
                if state.freezeTokensRemaining > 0 {
                    state.currentStreak += 1
                    state.freezeTokensRemaining -= 1
                    spentFreezeToken = true
                } else {
                    state.currentStreak = 1
                }
                state.lastCareDate = date
            }
        } else {
            state.currentStreak = 1
            state.lastCareDate = date
        }

        state.longestStreak = max(state.longestStreak, state.currentStreak)
        save()

        return StreakUpdate(
            current: state.currentStreak,
            longest: state.longestStreak,
            freezeTokensRemaining: state.freezeTokensRemaining,
            didAdvance: state.currentStreak > previous || state.lastCareDate == date && previous == 0,
            spentFreezeToken: state.freezeTokensRemaining < previousFreezeTokens || spentFreezeToken
        )
    }

    private func streakState() -> StreakState {
        let descriptor = FetchDescriptor<StreakState>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let state = StreakState()
        context.insert(state)
        save()
        return state
    }

    private func save() {
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Grow: streak save failed: \(error)")
            #endif
        }
    }
}

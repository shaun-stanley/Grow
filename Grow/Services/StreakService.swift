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

@MainActor
struct StreakTransaction {
    let state: StreakState
    let previousCurrent: Int
    let previousLongest: Int
    let previousLastDate: Date?
    let previousFreezeTokens: Int
    let update: StreakUpdate

    private let context: ModelContext
    private let insertedState: Bool

    init(
        state: StreakState,
        previousCurrent: Int,
        previousLongest: Int,
        previousLastDate: Date?,
        previousFreezeTokens: Int,
        update: StreakUpdate,
        context: ModelContext,
        insertedState: Bool
    ) {
        self.state = state
        self.previousCurrent = previousCurrent
        self.previousLongest = previousLongest
        self.previousLastDate = previousLastDate
        self.previousFreezeTokens = previousFreezeTokens
        self.update = update
        self.context = context
        self.insertedState = insertedState
    }

    func rollback() {
        state.currentStreak = previousCurrent
        state.longestStreak = previousLongest
        state.lastCareDate = previousLastDate
        state.freezeTokensRemaining = previousFreezeTokens
        if insertedState {
            context.delete(state)
        }
    }
}

nonisolated final class StreakService: Observable {
    private let context: ModelContext
    private let calendar: Calendar

    @MainActor
    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    @MainActor
    func snapshot() -> StreakUpdate {
        let (state, inserted) = streakState()
        if inserted {
            save()
        }
        return StreakUpdate(
            current: state.currentStreak,
            longest: state.longestStreak,
            freezeTokensRemaining: state.freezeTokensRemaining,
            didAdvance: false,
            spentFreezeToken: false
        )
    }

    @discardableResult
    @MainActor
    func recordCapture(at date: Date = Date()) -> StreakUpdate {
        let transaction = stageCapture(at: date)
        save()
        return transaction.update
    }

    @MainActor
    func stageCapture(at date: Date = Date()) -> StreakTransaction {
        let (state, insertedState) = streakState()
        let previous = state.currentStreak
        let previousLongest = state.longestStreak
        let previousLastDate = state.lastCareDate
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
        let update = StreakUpdate(
            current: state.currentStreak,
            longest: state.longestStreak,
            freezeTokensRemaining: state.freezeTokensRemaining,
            didAdvance: state.currentStreak > previous || state.lastCareDate == date && previous == 0,
            spentFreezeToken: state.freezeTokensRemaining < previousFreezeTokens || spentFreezeToken
        )
        return StreakTransaction(
            state: state,
            previousCurrent: previous,
            previousLongest: previousLongest,
            previousLastDate: previousLastDate,
            previousFreezeTokens: previousFreezeTokens,
            update: update,
            context: context,
            insertedState: insertedState
        )
    }

    @MainActor
    private func streakState() -> (state: StreakState, inserted: Bool) {
        let descriptor = FetchDescriptor<StreakState>()
        if let existing = try? context.fetch(descriptor).first {
            return (existing, false)
        }

        let state = StreakState()
        context.insert(state)
        return (state, true)
    }

    @MainActor
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

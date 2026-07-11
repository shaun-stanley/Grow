import SwiftData
import XCTest
@testable import Grow

@MainActor
final class StreakServiceTests: XCTestCase {
    private var containers: [ModelContainer] = []
    private var services: [StreakService] = []

    func testSameDayCaptureDoesNotAdvanceTwice() throws {
        let service = try makeService()
        let first = service.recordCapture(at: date(day: 1, hour: 9))
        let second = service.recordCapture(at: date(day: 1, hour: 17))

        XCTAssertEqual(first.current, 1)
        XCTAssertEqual(second.current, 1)
        XCTAssertFalse(second.didAdvance)
    }

    func testNextDayCaptureAdvancesStreak() throws {
        let service = try makeService()
        _ = service.recordCapture(at: date(day: 1))
        let update = service.recordCapture(at: date(day: 2))

        XCTAssertEqual(update.current, 2)
        XCTAssertTrue(update.didAdvance)
        XCTAssertFalse(update.spentFreezeToken)
    }

    func testMissedDayUsesFreezeToken() throws {
        let service = try makeService()
        _ = service.recordCapture(at: date(day: 1))
        let update = service.recordCapture(at: date(day: 3))

        XCTAssertEqual(update.current, 2)
        XCTAssertEqual(update.freezeTokensRemaining, 1)
        XCTAssertTrue(update.spentFreezeToken)
    }

    func testMissedDayWithoutFreezeResetsStreak() throws {
        let service = try makeService()
        _ = service.recordCapture(at: date(day: 1))
        _ = service.recordCapture(at: date(day: 3))
        _ = service.recordCapture(at: date(day: 5))
        let update = service.recordCapture(at: date(day: 7))

        XCTAssertEqual(update.current, 1)
        XCTAssertEqual(update.freezeTokensRemaining, 0)
        XCTAssertFalse(update.spentFreezeToken)
    }

    private func makeService() throws -> StreakService {
        let schema = Schema([StreakState.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        containers.append(container)
        let service = StreakService(context: ModelContext(container), calendar: calendar)
        services.append(service)
        return service
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(day: Int, hour: Int = 9) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 7,
            day: day,
            hour: hour
        ).date!
    }
}

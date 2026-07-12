import SwiftData
import XCTest
@testable import Grow

@MainActor
final class GrowPhotoOriginTests: XCTestCase {
    func testLegacyOriginIsMigrationSafeDefault() {
        let photo = GrowPhoto()

        XCTAssertEqual(photo.origin, .legacyUserMedia)
        XCTAssertNil(photo.sourceSampleID)
    }

    func testDemoOriginAndSourceIDSurviveContainerReconstruction() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: url) }

        let schema = GrowModelContainer.schema
        let first = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let photo = GrowPhoto(dayIndex: 7)
        photo.origin = .demoSample
        photo.sourceSampleID = "ojai-basil-day-07"
        first.mainContext.insert(photo)
        try first.mainContext.save()
        let id = photo.id

        let second = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let fetched = try XCTUnwrap(
            second.mainContext.fetch(FetchDescriptor<GrowPhoto>()).first { $0.id == id }
        )

        XCTAssertEqual(fetched.origin, .demoSample)
        XCTAssertEqual(fetched.sourceSampleID, "ojai-basil-day-07")
    }

    func testStableOrderingUsesDayThenDateThenUUID() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let laterDay = GrowPhoto(capturedAt: date.addingTimeInterval(-10), dayIndex: 2)
        let earlierDay = GrowPhoto(capturedAt: date, dayIndex: 1)
        let firstID = GrowPhoto(capturedAt: date, dayIndex: 1)
        let secondID = GrowPhoto(capturedAt: date, dayIndex: 1)
        firstID.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        secondID.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let sorted = [laterDay, secondID, earlierDay, firstID]
            .sorted(by: GrowPhotoOrdering.areInIncreasingOrder)

        XCTAssertEqual(sorted.first?.id, firstID.id)
        XCTAssertEqual(sorted.last?.id, laterDay.id)
    }
}

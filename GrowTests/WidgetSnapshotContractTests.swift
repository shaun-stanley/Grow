import XCTest
@testable import Grow

final class WidgetSnapshotContractTests: XCTestCase {
    func testAppPayloadRoundTripsThroughWidgetReader() throws {
        let suite = "WidgetSnapshotContractTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let snapshot = WidgetGrowSnapshot.sample
        defaults.set(
            try JSONEncoder().encode(snapshot),
            forKey: WidgetSnapshotKeys.activeGrowSnapshot
        )

        XCTAssertEqual(WidgetSnapshotReader(defaults: defaults).read(), snapshot)
    }

    func testReaderReturnsNilForMissingOrCorruptPayload() throws {
        let suite = "WidgetSnapshotCorrupt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertNil(WidgetSnapshotReader(defaults: defaults).read())

        defaults.set(
            Data("not-json".utf8),
            forKey: WidgetSnapshotKeys.activeGrowSnapshot
        )
        XCTAssertNil(WidgetSnapshotReader(defaults: defaults).read())
    }

    func testSnapshotSchemaStartsAtVersionOne() {
        XCTAssertEqual(WidgetGrowSnapshot.sample.schemaVersion, 1)
    }
}

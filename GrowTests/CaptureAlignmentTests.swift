import XCTest
@testable import Grow

final class CaptureAlignmentTests: XCTestCase {
    func testDecodesLegacyAlignmentWithoutSource() throws {
        let json = #"{"score":0.94,"xOffset":0.01,"yOffset":-0.02,"rotationDegrees":0}"#.data(using: .utf8)!
        let alignment = try JSONDecoder().decode(CaptureAlignment.self, from: json)
        XCTAssertEqual(alignment.source, .fallbackEstimate)
        XCTAssertEqual(alignment.sourceLabel, "Estimated match")
    }

    func testVisionAlignmentCopyIsHonest() {
        let alignment = CaptureAlignment(
            score: 0.98,
            xOffset: 0.001,
            yOffset: -0.001,
            rotationDegrees: 0,
            source: .visionTranslation
        )
        XCTAssertEqual(alignment.sourceLabel, "Vision matched")
        XCTAssertEqual(alignment.guidanceCopy, "Frame locked from the previous photo")
    }

    func testFallbackAlignmentCopyAvoidsOverclaiming() {
        let alignment = CaptureAlignment(
            score: 0.88,
            xOffset: 0.02,
            yOffset: 0.02,
            rotationDegrees: 0,
            source: .fallbackEstimate
        )
        XCTAssertEqual(alignment.sourceLabel, "Estimated match")
        XCTAssertEqual(alignment.guidanceCopy, "Saved with a steady-angle estimate")
    }
}

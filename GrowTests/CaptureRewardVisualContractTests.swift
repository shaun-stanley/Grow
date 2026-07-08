import XCTest
@testable import Grow

final class CaptureRewardVisualContractTests: XCTestCase {
    func testMetricCellsShareEqualLayoutContract() {
        XCTAssertEqual(CaptureRewardVisualContract.metricCellMinHeight, 112)
        XCTAssertEqual(CaptureRewardVisualContract.metricCellPadding, 16)
        XCTAssertEqual(CaptureRewardVisualContract.metricCellIconSize, 28)
        XCTAssertEqual(CaptureRewardVisualContract.receiptHeaderMinHeight, 84)
        XCTAssertEqual(CaptureRewardVisualContract.metricValueLineHeight, 38)
        XCTAssertEqual(CaptureRewardVisualContract.rewardScrollLeadIn, 16)
    }

    func testVisualQAChecklistRejectsGenericCardSlop() {
        let checklist = CaptureRewardVisualContract.antiSlopChecklist

        XCTAssertTrue(checklist.contains("Equal metric sizing and padding"))
        XCTAssertTrue(checklist.contains("Apple native system typography only"))
        XCTAssertTrue(checklist.contains("Matched receipt header columns"))
        XCTAssertTrue(checklist.contains("Metric values stay single-line"))
        XCTAssertTrue(checklist.contains("Metric units stay secondary to the primary number"))
        XCTAssertTrue(checklist.contains("Clear editorial reading order"))
        XCTAssertTrue(checklist.contains("No generic translucent card stack"))
        XCTAssertTrue(checklist.contains("No decorative icon bubbles without semantic purpose"))
    }
}

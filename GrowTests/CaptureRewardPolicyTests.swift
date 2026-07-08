import XCTest
@testable import Grow

final class CaptureRewardPolicyTests: XCTestCase {
    func testFirstWeekMilestones() {
        XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 1), "Your reel starts here")
        XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 3), "First streak milestone")
        XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 5), "Ahead of the curve")
        XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 7), "First week recap unlocked")
        XCTAssertNil(CaptureRewardPolicy.milestoneTitle(dayIndex: 8))
    }

    func testDayTwoNoteReassuresInvisibleGrowth() {
        let note = CaptureRewardPolicy.firstWeekNote(dayIndex: 2)
        XCTAssertEqual(note, "No visible change is normal. The reel is already getting steadier.")
    }

    func testDaySevenIsShareableFirstWeekArtifact() {
        XCTAssertEqual(CaptureRewardPolicy.firstWeekNote(dayIndex: 7), "One week of frames is enough to start seeing the story.")
        XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 7), "First week recap unlocked")
    }

    func testFutureReelProgressCapsAtOne() {
        XCTAssertEqual(CaptureRewardPolicy.futureReelProgress(frameCount: 15, targetFrameCount: 30), 0.5)
        XCTAssertEqual(CaptureRewardPolicy.futureReelProgress(frameCount: 45, targetFrameCount: 30), 1)
    }

    func testModeledGrowthStageBoundaries() {
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.10), .germination)
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.20), .seedling)
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.50), .vegetative)
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.75), .flowering)
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.90), .fruiting)
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.98), .harvest)
    }
}

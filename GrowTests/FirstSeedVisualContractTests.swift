import XCTest
@testable import Grow

final class FirstSeedVisualContractTests: XCTestCase {
    func testCeremonyProtectsNativeInteractionGeometry() {
        XCTAssertEqual(FirstSeedVisualContract.primaryActionHeight, 52)
        XCTAssertGreaterThanOrEqual(FirstSeedVisualContract.optionMinHeight, 64)
        XCTAssertEqual(FirstSeedVisualContract.launchCropCount, 3)
        XCTAssertEqual(FirstSeedVisualContract.launchSetupCount, 3)
    }

    func testSharedCameraUsesDayOneCopyWithoutGhostOverclaim() {
        let configuration = GuidedPlantCameraConfiguration.dayOne(
            speciesName: "Genovese basil"
        )

        XCTAssertEqual(configuration.title, "Frame one")
        XCTAssertNil(configuration.ghostThumbnailData)
        XCTAssertEqual(configuration.guidance, "Center the jar inside the guide")
    }

    func testCeremonyRejectsGenericQuestionnaireSlop() {
        let checklist = FirstSeedVisualContract.antiSlopChecklist

        XCTAssertTrue(checklist.contains("Apple native system typography only"))
        XCTAssertTrue(checklist.contains("One primary action per beat"))
        XCTAssertTrue(checklist.contains("Specimen-first composition"))
        XCTAssertTrue(checklist.contains("No nested card stacks"))
        XCTAssertTrue(checklist.contains("Bloom appears only after earned success"))
        XCTAssertTrue(checklist.contains("Selection uses glyph and label"))
        XCTAssertTrue(checklist.contains("Sample mode never persists"))
    }
}

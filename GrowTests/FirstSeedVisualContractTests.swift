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
}

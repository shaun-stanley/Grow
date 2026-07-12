import XCTest
@testable import Grow

@MainActor
final class OnboardingCoordinatorTests: XCTestCase {
    func testSelectionsAndBackNavigationRemainStable() async {
        let coordinator = OnboardingCoordinator()

        coordinator.begin()
        coordinator.selectSpecies("mint")
        coordinator.advanceFromCrop()
        coordinator.selectSetup(.countertopGarden)
        coordinator.goBack()

        XCTAssertEqual(coordinator.step, .crop)
        XCTAssertEqual(coordinator.selectedSpeciesID, "mint")
        XCTAssertEqual(coordinator.selectedSetup, .countertopGarden)
    }

    func testSampleModeNeverRequestsPersistence() async {
        let coordinator = OnboardingCoordinator()

        coordinator.showSample()

        XCTAssertEqual(coordinator.step, .sample)
        XCTAssertNil(coordinator.pendingGrowRequest)
    }

    func testSetupConfirmationProducesOneExplicitRequest() async {
        let coordinator = OnboardingCoordinator()
        coordinator.begin()
        coordinator.selectSpecies("lettuce")
        coordinator.advanceFromCrop()
        coordinator.selectSetup(.simpleJar)
        coordinator.confirmSetup()

        XCTAssertEqual(
            coordinator.pendingGrowRequest,
            OnboardingGrowRequest(speciesID: "lettuce", system: .kratky)
        )
        XCTAssertEqual(coordinator.step, .capture)
    }

    func testPreviewStartUsesRequestedBeatWithoutPersistence() async {
        let coordinator = OnboardingCoordinator()

        coordinator.start(at: .setup)

        XCTAssertEqual(coordinator.step, .setup)
        XCTAssertNil(coordinator.pendingGrowRequest)
        XCTAssertNil(coordinator.createdGrowID)
    }

    func testCaptureFailureKeepsCaptureVisibleAndOffersRetryCopy() async {
        let coordinator = OnboardingCoordinator()
        coordinator.start(at: .capture)

        coordinator.captureFailed(message: "That photo could not be saved. Try again or import one.")

        XCTAssertEqual(coordinator.step, .capture)
        XCTAssertEqual(coordinator.errorMessage, "That photo could not be saved. Try again or import one.")
        XCTAssertFalse(coordinator.canComplete)
    }

    func testSuccessfulCaptureMovesToRewardButRequiresCreatedGrowToComplete() async {
        let coordinator = OnboardingCoordinator()
        coordinator.start(at: .capture)

        coordinator.didCapture(Self.rewardFixture)

        XCTAssertEqual(coordinator.step, .reward)
        XCTAssertFalse(coordinator.canComplete)
        XCTAssertFalse(coordinator.complete())
    }

    func testCompletionRequiresCreatedGrowAndReward() async {
        let coordinator = OnboardingCoordinator()
        coordinator.start(at: .capture)
        coordinator.didCreateGrow(id: UUID())
        coordinator.didCapture(Self.rewardFixture)

        XCTAssertTrue(coordinator.canComplete)
        XCTAssertTrue(coordinator.complete())
        XCTAssertFalse(coordinator.canComplete)
    }

    private static var rewardFixture: CaptureReward {
        CaptureReward(
            photoID: UUID(),
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            dayIndex: 1,
            frameCount: 1,
            targetFrameCount: 30,
            alignment: CaptureAlignment(
                score: 0.94,
                xOffset: 0,
                yOffset: 0,
                rotationDegrees: 0,
                source: .prototype
            ),
            modeledProgressBefore: 0,
            modeledProgressAfter: 0.03,
            expectedStage: .germination,
            streak: StreakUpdate(
                current: 1,
                longest: 1,
                freezeTokensRemaining: 0,
                didAdvance: true,
                spentFreezeToken: false
            )
        )
    }
}

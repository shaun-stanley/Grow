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
}

import XCTest
@testable import Grow

final class OnboardingPolicyTests: XCTestCase {
    func testLaunchCropsStayFocusedAndDefaultToBasil() {
        XCTAssertEqual(OnboardingPolicy.launchSpeciesIDs, ["basil", "lettuce", "mint"])
        XCTAssertEqual(OnboardingPolicy.defaultSpeciesID, "basil")
    }

    func testSetupChoicesMapToLaunchSystems() {
        XCTAssertEqual(OnboardingPolicy.system(for: .simpleJar), .kratky)
        XCTAssertEqual(OnboardingPolicy.system(for: .countertopGarden), .dwc)
        XCTAssertEqual(OnboardingPolicy.system(for: .somethingElse), .other)
    }

    func testLaunchRoutingResumesInterruptedGrow() {
        XCTAssertEqual(
            OnboardingPolicy.launchRoute(
                completedVersion: 0,
                hasActiveGrow: false,
                activePhotoCount: 0
            ),
            .ceremony
        )
        XCTAssertEqual(
            OnboardingPolicy.launchRoute(
                completedVersion: 0,
                hasActiveGrow: true,
                activePhotoCount: 0
            ),
            .resumeCapture
        )
        XCTAssertEqual(
            OnboardingPolicy.launchRoute(
                completedVersion: 0,
                hasActiveGrow: true,
                activePhotoCount: 1
            ),
            .app
        )
        XCTAssertEqual(
            OnboardingPolicy.launchRoute(
                completedVersion: 1,
                hasActiveGrow: false,
                activePhotoCount: 0
            ),
            .app
        )
    }

    func testForcedPreviewRelinquishesControlAfterCompletion() {
        XCTAssertTrue(
            OnboardingPolicy.shouldShowCeremony(
                route: .app,
                forcesPreview: true,
                didDismissPreview: false
            )
        )
        XCTAssertFalse(
            OnboardingPolicy.shouldShowCeremony(
                route: .app,
                forcesPreview: true,
                didDismissPreview: true
            )
        )
        XCTAssertTrue(
            OnboardingPolicy.shouldShowCeremony(
                route: .resumeCapture,
                forcesPreview: false,
                didDismissPreview: true
            )
        )
    }

    func testActiveCeremonyDoesNotDisappearWhenFirstPhotoPersists() {
        XCTAssertTrue(
            OnboardingPolicy.shouldShowCeremony(
                route: .app,
                forcesPreview: false,
                didDismissPreview: false,
                sessionActive: true
            )
        )
    }
}

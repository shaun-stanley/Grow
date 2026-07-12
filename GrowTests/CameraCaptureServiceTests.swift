import XCTest
@testable import Grow

final class CameraCaptureServiceTests: XCTestCase {
    func testDeniedCameraPreviewRequiresExplicitDebugArgument() {
        XCTAssertTrue(
            CameraCaptureService.shouldSimulateDenied(
                arguments: ["Grow", "-simulateCameraDenied"]
            )
        )
        XCTAssertFalse(
            CameraCaptureService.shouldSimulateDenied(arguments: ["Grow"])
        )
    }
}

import XCTest
@testable import Grow

final class ReelStudioPolicyTests: XCTestCase {
    func testProgressCapsAtFirstThirtyFrames() {
        XCTAssertEqual(ReelStudioPolicy.progress(frameCount: 0), 0)
        XCTAssertEqual(ReelStudioPolicy.progress(frameCount: 15), 0.5)
        XCTAssertEqual(ReelStudioPolicy.progress(frameCount: 45), 1)
    }

    func testProgressTextDescribesFirstThirtyFrameReel() {
        XCTAssertEqual(ReelStudioPolicy.progressText(frameCount: 0), "Frame 1 is waiting")
        XCTAssertEqual(ReelStudioPolicy.progressText(frameCount: 8), "27% of the first 30-frame reel")
        XCTAssertEqual(ReelStudioPolicy.progressText(frameCount: 30), "First 30-frame reel ready")
        XCTAssertEqual(ReelStudioPolicy.progressText(frameCount: 42), "First 30-frame reel ready")
    }

    func testDurationTextUsesSingleDecimalSecond() {
        XCTAssertEqual(ReelStudioPolicy.durationText(5.36), "5.4s")
        XCTAssertEqual(ReelStudioPolicy.durationText(12), "12.0s")
    }

    func testStatusPriority() {
        XCTAssertEqual(
            ReelStudioPolicy.status(
                frameCount: 0,
                isRendering: false,
                renderedFrameCount: nil,
                renderedDurationSeconds: nil,
                errorMessage: nil
            ),
            .noFrames
        )

        XCTAssertEqual(
            ReelStudioPolicy.status(
                frameCount: 8,
                isRendering: true,
                renderedFrameCount: nil,
                renderedDurationSeconds: nil,
                errorMessage: "Previous error"
            ),
            .rendering
        )

        XCTAssertEqual(
            ReelStudioPolicy.status(
                frameCount: 8,
                isRendering: false,
                renderedFrameCount: nil,
                renderedDurationSeconds: nil,
                errorMessage: "Writer failed"
            ),
            .failed("Writer failed")
        )

        XCTAssertEqual(
            ReelStudioPolicy.status(
                frameCount: 8,
                isRendering: false,
                renderedFrameCount: 8,
                renderedDurationSeconds: 5.36,
                errorMessage: nil
            ),
            .rendered(frameCount: 8, durationText: "5.4s")
        )

        XCTAssertEqual(
            ReelStudioPolicy.status(
                frameCount: 8,
                isRendering: false,
                renderedFrameCount: nil,
                renderedDurationSeconds: nil,
                errorMessage: nil
            ),
            .ready(progressPercent: 27)
        )
    }

    func testShareURLRequiresNonEmptyExistingLocalFile() {
        let container = URL(fileURLWithPath: "/tmp/GrowShareRoot", isDirectory: true)

        XCTAssertNil(
            ReelStudioPolicy.shareURL(
                localFileName: "",
                containerURL: container,
                fileExists: { _ in true }
            )
        )

        XCTAssertNil(
            ReelStudioPolicy.shareURL(
                localFileName: "Reels/missing.mov",
                containerURL: container,
                fileExists: { _ in false }
            )
        )

        let url = ReelStudioPolicy.shareURL(
            localFileName: "Reels/grow/reel.mov",
            containerURL: container,
            fileExists: { $0.path.hasSuffix("/Reels/grow/reel.mov") }
        )

        XCTAssertEqual(url?.path, "/tmp/GrowShareRoot/Reels/grow/reel.mov")
    }
}

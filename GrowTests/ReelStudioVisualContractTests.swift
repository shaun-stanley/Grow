import XCTest
@testable import Grow

final class ReelStudioVisualContractTests: XCTestCase {
    func testStudioLayoutConstantsProtectFirstViewport() {
        XCTAssertEqual(ReelStudioVisualContract.previewMaxWidth, 208)
        XCTAssertEqual(ReelStudioVisualContract.accessibilityPreviewMaxWidth, 164)
        XCTAssertEqual(ReelStudioVisualContract.previewAspectRatio, 9.0 / 16.0)
        XCTAssertEqual(ReelStudioVisualContract.posterDayFontSize, 52)
        XCTAssertEqual(ReelStudioVisualContract.accessibilityPosterDayFontSize, 34)
        XCTAssertEqual(ReelStudioVisualContract.accessibilityPosterStatusFontSize, 13)
        XCTAssertEqual(ReelStudioVisualContract.studioContentSpacing, 16)
        XCTAssertEqual(ReelStudioVisualContract.accessibilityContentSpacing, 12)
        XCTAssertEqual(ReelStudioVisualContract.primaryActionHeight, 52)
        XCTAssertEqual(ReelStudioVisualContract.shareButtonSize, 52)
        XCTAssertEqual(ReelStudioVisualContract.exportThumbnailWidth, 40)
        XCTAssertEqual(ReelStudioVisualContract.exportThumbnailHeight, 54)
        XCTAssertEqual(ReelStudioVisualContract.exportRowVerticalPadding, 10)
        XCTAssertEqual(ReelStudioVisualContract.exportRowHorizontalPadding, 12)
        XCTAssertEqual(ReelStudioVisualContract.bottomScrollPadding, 96)
    }

    func testAntiSlopChecklistCoversReelsSpecificDesignRisks() {
        let checklist = ReelStudioVisualContract.antiSlopChecklist

        XCTAssertTrue(checklist.contains("Apple native system typography only"))
        XCTAssertTrue(checklist.contains("Preview, action, and status visible in first viewport"))
        XCTAssertTrue(checklist.contains("Even padding inside Reels surfaces"))
        XCTAssertTrue(checklist.contains("No nested-card effect"))
        XCTAssertTrue(checklist.contains("Share icon aligned to primary action height"))
        XCTAssertTrue(checklist.contains("Export rows use fixed 9:16 thumbnails"))
        XCTAssertTrue(checklist.contains("No generic AI-generated mobile card stack"))
    }
}

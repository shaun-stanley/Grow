import UIKit
import XCTest
@testable import Grow

final class DemoGrowPhotoLibraryTests: XCTestCase {
    func testSparseDayChoosesNearestPriorFrame() throws {
        let library = try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [
                frame(id: "d1", day: 1, sequence: 0),
                frame(id: "d7", day: 7, sequence: 1)
            ]),
            assetData: { _ in Self.validJPEG }
        )

        XCTAssertEqual(try library.frame(forDay: 5).id, "d1")
        XCTAssertEqual(try library.frame(forDay: 40).id, "d7")
    }

    func testDayBeforeFirstMasterFails() throws {
        let library = try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [frame(id: "d1", day: 1, sequence: 0)]),
            assetData: { _ in Self.validJPEG }
        )

        XCTAssertThrowsError(try library.frame(forDay: 0)) {
            XCTAssertEqual($0 as? DemoGrowPhotoLibraryError, .noPriorMaster)
        }
    }

    func testDuplicateIDAndSequenceRejectManifest() {
        XCTAssertThrowsError(try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [
                frame(id: "same", day: 1, sequence: 0),
                frame(id: "same", day: 2, sequence: 1)
            ]),
            assetData: { _ in Self.validJPEG }
        ))
        XCTAssertThrowsError(try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [
                frame(id: "a", day: 1, sequence: 0),
                frame(id: "b", day: 2, sequence: 0)
            ]),
            assetData: { _ in Self.validJPEG }
        ))
    }

    func testMissingOrCorruptReferencedAssetRejectsManifest() {
        XCTAssertThrowsError(try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [frame(id: "d1", day: 1, sequence: 0)]),
            assetData: { _ in nil }
        ))
        XCTAssertThrowsError(try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [frame(id: "d1", day: 1, sequence: 0)]),
            assetData: { _ in Data("not-image".utf8) }
        ))
    }

    func testDuplicateDayOrdersBySequence() throws {
        let library = try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [
                frame(id: "harvest", day: 30, sequence: 11),
                frame(id: "mature", day: 30, sequence: 9)
            ]),
            assetData: { _ in Self.validJPEG }
        )

        XCTAssertEqual(try library.reelFrames().map(\.id), ["mature", "harvest"])
    }

    private func frame(id: String, day: Int, sequence: Int) -> DemoGrowPhotoFrame {
        DemoGrowPhotoFrame(
            id: id,
            fileName: "\(id).jpg",
            day: day,
            sequence: sequence,
            moment: .ordinary,
            focalPoints: Dictionary(
                uniqueKeysWithValues: DemoGrowCropIntent.allCases.map {
                    ($0, NormalizedPoint(x: 0.5, y: 0.5))
                }
            ),
            accessibilityKey: "\(id)_accessibility"
        )
    }

    private func manifestData(frames: [DemoGrowPhotoFrame]) -> Data {
        try! JSONEncoder().encode(
            DemoGrowPhotoManifest(
                schemaVersion: 1,
                storyID: "test-story",
                maximumOrdinaryDay: 30,
                frames: frames
            )
        )
    }

    private static let validJPEG: Data = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }()
}

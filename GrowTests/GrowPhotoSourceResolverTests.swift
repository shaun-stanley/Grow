import UIKit
import XCTest
@testable import Grow

final class GrowPhotoSourceResolverTests: XCTestCase {
    func testFullSizeRetainsStoredDemoProvenance() async throws {
        let photo = makePhoto(origin: .demoSample, sampleID: "ojai-basil-day-07")
        let resolver = makeResolver(fullSizeData: Self.validJPEG)

        let resolved = try await resolver.resolve(
            photo: photo,
            policy: .demoAllowed,
            targetMaxPixel: 512
        )

        XCTAssertEqual(resolved.provenance, .demoSample(sampleID: "ojai-basil-day-07"))
        XCTAssertEqual(resolved.quality, .fullSize)
        XCTAssertEqual(resolved.sampleID, "ojai-basil-day-07")
    }

    func testGenuineThumbnailOutranksRecoverySample() async throws {
        let photo = makePhoto(origin: .camera, thumbnailData: Self.validJPEG)
        let recoveryAsset = sampleAsset(id: "ojai-basil-day-07", day: 7)
        let resolver = makeResolver(recoveryAsset: recoveryAsset)

        let resolved = try await resolver.resolve(
            photo: photo,
            policy: .interactiveRecoveryAllowed(day: 7),
            targetMaxPixel: 512
        )

        XCTAssertEqual(resolved.provenance, .camera)
        XCTAssertEqual(resolved.quality, .thumbnail)
        XCTAssertNil(resolved.sampleID)
    }

    func testGenuineOnlyRejectsMissingUserMedia() async throws {
        let photo = makePhoto(origin: .photoLibrary)
        let resolver = makeResolver()

        await XCTAssertThrowsErrorAsync(
            try await resolver.resolve(
                photo: photo,
                policy: .genuineMediaOnly,
                targetMaxPixel: 512
            )
        ) {
            XCTAssertEqual($0 as? GrowPhotoResolutionError, .missingGenuineMedia)
        }
    }

    func testDemoPolicyRejectsCameraRecordSampleSubstitution() async throws {
        let photo = makePhoto(origin: .camera)
        let resolver = makeResolver(
            sampleByID: sampleAsset(id: "ojai-basil-day-07", day: 7)
        )

        await XCTAssertThrowsErrorAsync(
            try await resolver.resolve(
                photo: photo,
                policy: .demoAllowed,
                targetMaxPixel: 512
            )
        ) {
            XCTAssertEqual($0 as? GrowPhotoResolutionError, .policyViolation)
        }
    }

    func testInteractiveRecoveryLabelsSampleWithoutMutatingRecord() async throws {
        let photo = makePhoto(origin: .legacyUserMedia)
        let originalOrigin = photo.origin
        let originalSampleID = photo.sourceSampleID
        let originalFileName = photo.localFileName
        let recoveryAsset = sampleAsset(id: "ojai-basil-day-14", day: 14)
        let resolver = makeResolver(recoveryAsset: recoveryAsset)

        let resolved = try await resolver.resolve(
            photo: photo,
            policy: .interactiveRecoveryAllowed(day: 14),
            targetMaxPixel: 512
        )

        XCTAssertEqual(resolved.provenance, .recoverySample(sampleID: "ojai-basil-day-14"))
        XCTAssertEqual(resolved.quality, .fallback)
        XCTAssertEqual(resolved.sampleID, "ojai-basil-day-14")
        XCTAssertEqual(photo.origin, originalOrigin)
        XCTAssertEqual(photo.sourceSampleID, originalSampleID)
        XCTAssertEqual(photo.localFileName, originalFileName)
    }

    func testAppGroupLocationDoesNotReclassifyDemoSample() async throws {
        let photo = makePhoto(
            origin: .demoSample,
            sampleID: "ojai-basil-day-21",
            localFileName: "Photos/user-looking-path.jpg"
        )
        let resolver = makeResolver(fullSizeData: Self.validJPEG)

        let resolved = try await resolver.resolve(
            photo: photo,
            policy: .demoAllowed,
            targetMaxPixel: 512
        )

        XCTAssertEqual(resolved.provenance, .demoSample(sampleID: "ojai-basil-day-21"))
        XCTAssertEqual(resolved.quality, .fullSize)
    }

    private func makePhoto(
        origin: GrowPhotoOrigin,
        sampleID: String? = nil,
        thumbnailData: Data? = nil,
        localFileName: String = "Photos/test.jpg"
    ) -> GrowPhoto {
        let photo = GrowPhoto(capturedAt: .now, dayIndex: 7)
        photo.origin = origin
        photo.sourceSampleID = sampleID
        photo.thumbnailData = thumbnailData
        photo.localFileName = localFileName
        return photo
    }

    private func makeResolver(
        fullSizeData: Data? = nil,
        sampleByID: DemoGrowPhotoAsset? = nil,
        recoveryAsset: DemoGrowPhotoAsset? = nil
    ) -> GrowPhotoSourceResolver {
        GrowPhotoSourceResolver(
            decoder: GrowImageDecoder(),
            fullSizeData: { _ in fullSizeData },
            demoAssetByID: { _ in sampleByID },
            demoAssetForDay: { _ in recoveryAsset }
        )
    }

    private func sampleAsset(id: String, day: Int) -> DemoGrowPhotoAsset {
        DemoGrowPhotoAsset(
            frame: DemoGrowPhotoFrame(
                id: id,
                fileName: "\(id).jpg",
                day: day,
                sequence: day,
                moment: .ordinary,
                focalPoints: Dictionary(
                    uniqueKeysWithValues: DemoGrowCropIntent.allCases.map {
                        ($0, NormalizedPoint(x: 0.5, y: 0.5))
                    }
                ),
                accessibilityKey: "\(id)_accessibility"
            ),
            data: Self.validJPEG
        )
    }

    private static let validJPEG: Data = {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 64)).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 48, height: 64))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }()
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

import SwiftData
import UIKit
import XCTest
@testable import Grow

@MainActor
final class PhotoServiceOriginTests: XCTestCase {
    func testCameraCapturePersistsCameraOrigin() throws {
        let fixture = try makeFixture()
        defer { removePhotoDirectory(for: fixture.grow) }

        let reward = try fixture.service.recordCapture(
            imageData: try imageData(),
            origin: .camera,
            for: fixture.grow,
            species: nil
        )

        let photo = try XCTUnwrap(fixture.grow.photos?.first { $0.id == reward.photoID })
        XCTAssertEqual(photo.origin, .camera)
        XCTAssertNil(photo.sourceSampleID)
    }

    func testPhotoLibraryCapturePersistsPhotoLibraryOrigin() throws {
        let fixture = try makeFixture()
        defer { removePhotoDirectory(for: fixture.grow) }

        let reward = try fixture.service.recordCapture(
            imageData: try imageData(),
            origin: .photoLibrary,
            for: fixture.grow,
            species: nil
        )

        let photo = try XCTUnwrap(fixture.grow.photos?.first { $0.id == reward.photoID })
        XCTAssertEqual(photo.origin, .photoLibrary)
        XCTAssertNil(photo.sourceSampleID)
    }

    func testDemoCapturePersistsSelectedSampleOriginAndID() async throws {
        let fixture = try makeFixture()
        defer { removePhotoDirectory(for: fixture.grow) }

        let reward = try await fixture.service.recordDemoCapture(
            for: fixture.grow,
            species: nil,
            capturedAt: fixture.grow.startDate
        )

        let photo = try XCTUnwrap(fixture.grow.photos?.first { $0.id == reward.photoID })
        XCTAssertEqual(photo.origin, .demoSample)
        XCTAssertEqual(photo.sourceSampleID, "ojai-basil-day-01")
    }

    func testReconstructedContainerRetainsDemoProvenance() async throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let schema = GrowModelContainer.schema
        let first = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let grow = Grow(speciesID: "basil", system: .kratky)
        first.mainContext.insert(grow)
        try first.mainContext.save()
        defer { removePhotoDirectory(for: grow) }
        let service = PhotoService(
            context: first.mainContext,
            streakService: StreakService(context: first.mainContext),
            demoLibrary: try .bundled()
        )
        let reward = try await service.recordDemoCapture(
            for: grow,
            species: nil,
            capturedAt: grow.startDate
        )

        let second = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let fetched = try XCTUnwrap(
            second.mainContext.fetch(FetchDescriptor<GrowPhoto>()).first { $0.id == reward.photoID }
        )
        XCTAssertEqual(fetched.origin, .demoSample)
        XCTAssertEqual(fetched.sourceSampleID, "ojai-basil-day-01")
    }

    func testGenuineCaptureRejectsDemoOrigin() throws {
        let fixture = try makeFixture()
        defer { removePhotoDirectory(for: fixture.grow) }

        XCTAssertThrowsError(
            try fixture.service.recordCapture(
                imageData: try imageData(),
                origin: .demoSample,
                for: fixture.grow,
                species: nil
            )
        ) {
            XCTAssertEqual($0 as? PhotoServiceError, .invalidCaptureOrigin)
        }
        XCTAssertTrue((fixture.grow.photos ?? []).isEmpty)
    }

    private func makeFixture() throws -> OriginFixture {
        let schema = GrowModelContainer.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let grow = Grow(speciesID: "basil", system: .kratky)
        context.insert(grow)
        try context.save()
        let service = PhotoService(
            context: context,
            streakService: StreakService(context: context),
            demoLibrary: try .bundled()
        )
        return OriginFixture(container: container, grow: grow, service: service)
    }

    private func imageData() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 180))
        let image = renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 180))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
    }

    private func removePhotoDirectory(for grow: Grow) {
        let directory = AppGroup.photosDirectory
            .appendingPathComponent(grow.id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }
}

private struct OriginFixture {
    let container: ModelContainer
    let grow: Grow
    let service: PhotoService
}

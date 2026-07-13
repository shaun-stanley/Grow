import SwiftData
import UIKit
import XCTest
@testable import Grow

@MainActor
final class PhotoServiceTransactionTests: XCTestCase {
    func testServiceLifetimeWithoutCaptureDoesNotCrash() throws {
        let fixture = try makeFixture()
        let service = PhotoService(
            context: fixture.context,
            streakService: fixture.streakService,
            demoLibrary: nil
        )

        XCTAssertNotNil(service)
    }

    func testThumbnailFailureLeavesNoFileModelGrowOrStreakChanges() throws {
        let fixture = try makeFixture()
        defer { removePhotoDirectory(for: fixture.grow) }
        let initialStreak = fixture.streakService.snapshot()

        let service = PhotoService(
            context: fixture.context,
            streakService: fixture.streakService,
            demoLibrary: nil,
            thumbnailEncoder: FailingThumbnailEncoder()
        )

        XCTAssertThrowsError(
            try service.recordCapture(
                imageData: try imageData(),
                origin: .camera,
                for: fixture.grow,
                species: nil
            )
        )

        assertNoCaptureChanges(
            fixture: fixture,
            initialStreak: initialStreak
        )
    }

    func testMetadataSaveFailureRemovesFileAndRestoresGrowAndStreak() throws {
        let fixture = try makeFixture()
        defer { removePhotoDirectory(for: fixture.grow) }
        let initialStreak = fixture.streakService.snapshot()

        let service = PhotoService(
            context: fixture.context,
            streakService: fixture.streakService,
            demoLibrary: nil,
            contextSaver: FailingContextSaver()
        )

        XCTAssertThrowsError(
            try service.recordCapture(
                imageData: try imageData(),
                origin: .photoLibrary,
                for: fixture.grow,
                species: nil
            )
        )

        assertNoCaptureChanges(
            fixture: fixture,
            initialStreak: initialStreak
        )
    }

    func testSuccessfulCaptureCommitsPhotoGrowAndStreakOnce() throws {
        let fixture = try makeFixture()
        defer { removePhotoDirectory(for: fixture.grow) }
        let contextSaver = CountingContextSaver()
        let service = PhotoService(
            context: fixture.context,
            streakService: fixture.streakService,
            demoLibrary: nil,
            contextSaver: contextSaver
        )

        let reward = try service.recordCapture(
            imageData: try imageData(),
            origin: .camera,
            for: fixture.grow,
            species: nil
        )

        XCTAssertEqual(contextSaver.saveCount, 1)
        XCTAssertEqual(fixture.grow.photos?.count, 1)
        XCTAssertEqual(fixture.grow.photos?.first?.origin, .camera)
        XCTAssertEqual(fixture.grow.coverPhotoID, reward.photoID)
        XCTAssertEqual(fixture.grow.currentStage, reward.expectedStage)
        XCTAssertEqual(fixture.streakService.snapshot().current, 1)
    }

    private func assertNoCaptureChanges(
        fixture: Fixture,
        initialStreak: StreakUpdate,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNil(fixture.grow.coverPhotoID, file: file, line: line)
        XCTAssertEqual(fixture.grow.currentStage, .germination, file: file, line: line)
        XCTAssertTrue((fixture.grow.photos ?? []).isEmpty, file: file, line: line)
        XCTAssertEqual(fixture.streakService.snapshot(), initialStreak, file: file, line: line)

        let growDirectory = AppGroup.photosDirectory
            .appendingPathComponent(fixture.grow.id.uuidString, isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: growDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        XCTAssertTrue(files.isEmpty, file: file, line: line)
    }

    private func makeFixture() throws -> Fixture {
        let schema = GrowModelContainer.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let grow = Grow(speciesID: "basil", system: .kratky)
        context.insert(grow)
        try context.save()
        return Fixture(
            container: container,
            context: context,
            grow: grow,
            streakService: StreakService(context: context)
        )
    }

    private func removePhotoDirectory(for grow: Grow) {
        let directory = AppGroup.photosDirectory
            .appendingPathComponent(grow.id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }

    private func imageData() throws -> Data {
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 120, height: 180)
        )
        let image = renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 180))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
    }
}

private struct Fixture {
    let container: ModelContainer
    let context: ModelContext
    let grow: Grow
    let streakService: StreakService
}

private struct MetadataFailure: Error {}
private struct ThumbnailFailure: Error {}

private final class FailingThumbnailEncoder: PhotoThumbnailEncoder {
    override func data(from image: UIImage) throws -> Data {
        throw ThumbnailFailure()
    }
}

private final class FailingContextSaver: PhotoContextSaver {
    override func save(_ context: ModelContext) throws {
        throw MetadataFailure()
    }
}

private final class CountingContextSaver: PhotoContextSaver {
    private(set) var saveCount = 0

    override func save(_ context: ModelContext) throws {
        saveCount += 1
        try context.save()
    }
}

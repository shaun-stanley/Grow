import SwiftData
import UIKit
import XCTest
@testable import Grow

@MainActor
final class PhotoServiceTransactionTests: XCTestCase {
    func testMetadataSaveFailureRemovesFileAndRestoresGrow() async throws {
        let schema = GrowModelContainer.schema
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let context = container.mainContext
        let grow = Grow(speciesID: "basil", system: .kratky)
        context.insert(grow)
        try context.save()

        let service = PhotoService(
            context: context,
            streakService: StreakService(context: context),
            saveContext: { _ in throw MetadataFailure() }
        )

        XCTAssertThrowsError(
            try service.recordCapture(
                imageData: try imageData(),
                for: grow,
                species: nil
            )
        )

        XCTAssertNil(grow.coverPhotoID)
        XCTAssertEqual(grow.currentStage, .germination)
        XCTAssertTrue((grow.photos ?? []).isEmpty)

        let growDirectory = AppGroup.photosDirectory
            .appendingPathComponent(grow.id.uuidString, isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: growDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        XCTAssertTrue(files.isEmpty)
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

private struct MetadataFailure: Error {}

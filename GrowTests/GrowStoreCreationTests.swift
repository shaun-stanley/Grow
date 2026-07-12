import SwiftData
import XCTest
@testable import Grow

@MainActor
final class GrowStoreCreationTests: XCTestCase {
    func testCreateGrowPersistsSelectedSpeciesAndSeedsCareTasks() async throws {
        let container = try makeContainer()
        let store = GrowStore(
            context: container.mainContext,
            catalog: PlantCatalogService()
        )

        let grow = try store.createGrow(
            speciesID: "basil",
            nickname: "",
            system: .kratky
        )

        XCTAssertEqual(grow.speciesID, "basil")
        XCTAssertEqual(grow.system, .kratky)
        XCTAssertFalse((grow.careTasks ?? []).isEmpty)
        XCTAssertEqual(store.activeGrows().map(\.id), [grow.id])
    }

    func testDeleteRemovesAbandonedGrow() async throws {
        let container = try makeContainer()
        let store = GrowStore(
            context: container.mainContext,
            catalog: PlantCatalogService()
        )
        let grow = try store.createGrow(
            speciesID: "basil",
            nickname: "",
            system: .kratky
        )

        try store.delete(grow)

        XCTAssertTrue(store.activeGrows().isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = GrowModelContainer.schema
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}

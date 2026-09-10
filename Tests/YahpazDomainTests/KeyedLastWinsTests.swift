import XCTest
@testable import YahpazDomain

final class KeyedLastWinsTests: XCTestCase {
    func testOverlappingIdsDoNotTrapAndKeepLast() {
        let result = keyedLastWins([
            ("evt-1", "unit"),
            ("evt-1", "active"),
            ("evt-2", "unit"),
            ("evt-1", "pinned"),
        ])
        XCTAssertEqual(result["evt-1"], "pinned")
        XCTAssertEqual(result["evt-2"], "unit")
        XCTAssertEqual(result.count, 2)
    }

    func testEmptyPairsYieldEmptyDictionary() {
        let result: [String: String] = keyedLastWins([])
        XCTAssertTrue(result.isEmpty)
    }

    func testCatalogMergeOfOverlappingEventIdsKeepsLastList() {
        let unit = [
            CatalogRow(id: "evt-1", source: "unit"),
            CatalogRow(id: "evt-2", source: "unit"),
        ]
        let myActive = [
            CatalogRow(id: "evt-1", source: "active"),
            CatalogRow(id: "evt-3", source: "active"),
        ]
        let pinned = [
            CatalogRow(id: "evt-1", source: "pinned"),
        ]
        let catalog = mergeIdentifiedLastWins(unit, myActive, pinned)
        XCTAssertEqual(catalog["evt-1"]?.source, "pinned")
        XCTAssertEqual(catalog["evt-2"]?.source, "unit")
        XCTAssertEqual(catalog["evt-3"]?.source, "active")
        XCTAssertEqual(catalog.count, 3)
    }

    func testIdentifiableOverloadLastWinsOnDuplicateShiftIds() {
        let byId = keyedLastWins([
            CatalogRow(id: "shift-1", source: "first"),
            CatalogRow(id: "shift-1", source: "second"),
        ])
        XCTAssertEqual(byId["shift-1"]?.source, "second")
        XCTAssertEqual(byId.count, 1)
    }
}

private struct CatalogRow: Identifiable, Equatable {
    let id: String
    let source: String
}

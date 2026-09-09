import XCTest
@testable import YahpazDomain

final class HighwayJunctionsTests: XCTestCase {
    private let catalog = [
        HighwayJunctionCatalogRow(
            id: "1",
            nameHe: "צומת אהרונסון",
            nameEn: "Aharonson",
            roads: "4/721 (דרומי)",
            lat: 32.71,
            lng: 34.97
        ),
        HighwayJunctionCatalogRow(
            id: "2",
            nameHe: "צומת מסובים",
            nameEn: "Mesubim",
            roads: "4/461",
            lat: 32.03,
            lng: 34.84,
            aliasesHe: ["מסובים"]
        ),
        HighwayJunctionCatalogRow(
            id: "3",
            nameHe: "מחלף גלילות",
            nameEn: "Glilot",
            roads: "2/5",
            lat: 32.15,
            lng: 34.81
        ),
    ]

    private let roads = [
        LookupOption(id: "r4", name: "כביש 4"),
        LookupOption(id: "r40", name: "40"),
        LookupOption(id: "r44", name: "כביש 44"),
        LookupOption(id: "r5", name: "כביש5"),
        LookupOption(id: "r6", name: "6"),
        LookupOption(id: "urban", name: "עירוני (101)"),
    ]

    func testJunctionPlaceIdRoundTrips() {
        let id = "11111111-1111-1111-1111-111111111111"
        XCTAssertEqual(junctionIdFromPlaceId(junctionPlaceId(id)), id)
        XCTAssertNil(junctionIdFromPlaceId("ChIJx"))
        XCTAssertNil(junctionIdFromPlaceId(nil))
    }

    func testRankPrefersExactAndPrefixOverFuzzy() {
        XCTAssertEqual(rankHighwayJunctions(catalog, query: "מסובים").first?.nameHe, "צומת מסובים")
    }

    func testTypoAndTranspositionMatch() {
        XCTAssertTrue(rankHighwayJunctions(catalog, query: "אהרונסן").map(\.nameHe).contains("צומת אהרונסון"))
        XCTAssertTrue(rankHighwayJunctions(catalog, query: "מסבוים").map(\.nameHe).contains("צומת מסובים"))
        XCTAssertEqual(junctionEditDistance("מסובים", "מסבוים"), 1)
    }

    func testTrailingDirectionIsIgnoredForSearch() {
        XCTAssertTrue(
            rankHighwayJunctions(catalog, query: "אהרונסון למערב").map(\.nameHe).contains("צומת אהרונסון")
        )
        XCTAssertTrue(
            rankHighwayJunctions(catalog, query: "מחלף גלילות לכיוון צפון").map(\.nameHe).contains("מחלף גלילות")
        )
    }

    func testSplitCommonTrailingDirectionVariants() {
        XCTAssertEqual(
            splitJunctionDirection("צומת אהרונסון למערב"),
            JunctionQueryParts(baseQuery: "צומת אהרונסון", directionSuffix: "למערב")
        )
        XCTAssertEqual(
            splitJunctionDirection("גלילות לכיוון צפון"),
            JunctionQueryParts(baseQuery: "גלילות", directionSuffix: "לכיוון צפון")
        )
    }

    func testTypedDirectionIsPreservedOnSelect() {
        XCTAssertEqual(
            junctionLocationLabel(junctionName: "צומת אהרונסון", typedQuery: "אהרונסון למערב"),
            "צומת אהרונסון למערב"
        )
        XCTAssertEqual(
            junctionLocationLabel(junctionName: "צומת רמלה צפון", typedQuery: "צומת רמלה צפון"),
            "צומת רמלה צפון"
        )
    }

    func testFirstNumericJunctionRoadToken() {
        XCTAssertEqual(firstJunctionRoadNumber("4/721 (דרומי)"), "4")
        XCTAssertEqual(firstJunctionRoadNumber(" 5 /אל כרים קאסם (כפר קאסם)"), "5")
        XCTAssertEqual(firstJunctionRoadNumber("כביש 4/721"), "4")
        XCTAssertEqual(firstJunctionRoadNumber("כביש4/721"), "4")
        XCTAssertEqual(firstJunctionRoadNumber("אל כרים קאסם/5"), "5")
        XCTAssertNil(firstJunctionRoadNumber(nil))
    }

    func testExactRoadNumbersFromLookupLabels() {
        XCTAssertEqual(roadNumberFromLookupName("6"), "6")
        XCTAssertEqual(roadNumberFromLookupName(" כביש 6 "), "6")
        XCTAssertEqual(roadNumberFromLookupName("כביש6"), "6")
        XCTAssertEqual(roadNumberFromLookupName("כביש 6 (צפון)"), "6")
        XCTAssertNil(roadNumberFromLookupName("עירוני (101)"))
    }

    func testFirstRoadMatchesExactlyWithoutConfusing4With40() {
        XCTAssertEqual(matchingRoadIdForJunction("4/721 (דרומי)", lookups: roads), "r4")
        XCTAssertEqual(matchingRoadIdForJunction("40/406", lookups: roads), "r40")
    }

    func testLaterNumericTokensAndNoMatch() {
        XCTAssertEqual(matchingRoadIdForJunction("אל כרים קאסם/5", lookups: roads), "r5")
        XCTAssertNil(matchingRoadIdForJunction("90/57", lookups: roads))
        XCTAssertEqual(
            matchingRoadIdForJunction("6/40", lookups: roads + [LookupOption(id: "r6-duplicate", name: "כביש 6")]),
            "r40"
        )
    }

    func testJunctionOverwritesExistingRoadOnlyWhenResolved() {
        XCTAssertEqual(roadIdAfterJunctionSelection(currentRoadId: "", junctionRoads: "4/721", lookups: roads), "r4")
        XCTAssertEqual(roadIdAfterJunctionSelection(currentRoadId: "", junctionRoads: "90/57", lookups: roads), "")
        XCTAssertEqual(roadIdAfterJunctionSelection(currentRoadId: "r44", junctionRoads: "4/721", lookups: roads), "r4")
        XCTAssertEqual(roadIdAfterJunctionSelection(currentRoadId: "r44", junctionRoads: "90/57", lookups: roads), "r44")
    }

    func testEmptyQueryRanksNothing() {
        XCTAssertTrue(rankHighwayJunctions(catalog, query: "").isEmpty)
        XCTAssertTrue(rankHighwayJunctions(catalog, query: "   ").isEmpty)
    }
}

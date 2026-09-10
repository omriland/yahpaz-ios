import XCTest
@testable import YahpazDomain

final class LocationSuggestionsTests: XCTestCase {
    private let junction = HighwayJunction(
        id: "junction-1",
        nameHe: "מחלף השלום",
        roads: "20",
        lat: 32.073,
        lng: 34.793
    )
    private let google = PlacePrediction(
        placeId: "google-1",
        primaryText: "מחלף השלום",
        secondaryText: "תל אביב"
    )

    func testCombinedSearchQueriesBothSources() async {
        let result = await searchLocationSuggestionsCombined(
            localQuery: "השלום",
            googleQuery: "כביש 20 השלום",
            sessionToken: "session-1",
            searchJunctions: { query in
                XCTAssertEqual(query, "השלום")
                return [self.junction]
            },
            searchPlaces: { query, token in
                XCTAssertEqual(query, "כביש 20 השלום")
                XCTAssertEqual(token, "session-1")
                return .ok([PlacePrediction(placeId: "google-1", primaryText: "השלום", secondaryText: "תל אביב")])
            }
        )
        XCTAssertEqual(result.junctions, [junction])
        XCTAssertFalse(result.localFailed)
        if case .ok(let predictions) = result.places {
            XCTAssertEqual(predictions.map(\.placeId), ["google-1"])
        } else {
            XCTFail("expected google predictions")
        }
    }

    func testCombinedSearchKeepsGoogleWhenJunctionsFail() async {
        let result = await searchLocationSuggestionsCombined(
            localQuery: "השלום",
            googleQuery: "השלום",
            sessionToken: "session-1",
            searchJunctions: { _ in throw TestError.localUnavailable },
            searchPlaces: { _, _ in .ok([]) }
        )
        XCTAssertTrue(result.junctions.isEmpty)
        XCTAssertTrue(result.localFailed)
        XCTAssertEqual(result.places, .ok([]))
    }

    func testRankPutsJunctionsFirstThenGoogleThenFreeText() {
        XCTAssertEqual(
            rankLocationSuggestions(
                junctions: [junction],
                predictions: [google],
                freeText: "השלום",
                allowFreeText: true
            ),
            [.junction(junction), .google(google), .freeText("השלום")]
        )
    }

    func testRankKeepsFreeTextWhenNothingMatches() {
        XCTAssertEqual(
            rankLocationSuggestions(junctions: [], predictions: [], freeText: " מקום שלא נמצא ", allowFreeText: true),
            [.freeText("מקום שלא נמצא")]
        )
    }

    func testRankOmitsFreeTextWhenDisallowed() {
        XCTAssertEqual(
            rankLocationSuggestions(junctions: [], predictions: [google], freeText: "השלום", allowFreeText: false),
            [.google(google)]
        )
    }

    func testEventGeocodeQueryPrefersRoadNumber() {
        XCTAssertEqual(eventGeocodeQuery(road: "כביש 6", location: "מסובים"), "כביש 6 מסובים")
        XCTAssertEqual(eventGeocodeQuery(road: nil, location: "מסובים"), "מסובים")
        XCTAssertNil(eventGeocodeQuery(road: nil, location: "  "))
    }
}

private enum TestError: Error {
    case localUnavailable
}

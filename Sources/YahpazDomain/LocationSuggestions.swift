import Foundation

public struct PlacePrediction: Equatable, Sendable {
    public var placeId: String
    public var primaryText: String
    public var secondaryText: String

    public init(placeId: String, primaryText: String, secondaryText: String = "") {
        self.placeId = placeId
        self.primaryText = primaryText
        self.secondaryText = secondaryText
    }
}

public enum PlacesSearchResult: Equatable, Sendable {
    case ok([PlacePrediction])
    case failed(String)
}

public struct CombinedSearchResult: Equatable, Sendable {
    public var junctions: [HighwayJunction]
    public var places: PlacesSearchResult
    public var localFailed: Bool

    public init(junctions: [HighwayJunction], places: PlacesSearchResult, localFailed: Bool) {
        self.junctions = junctions
        self.places = places
        self.localFailed = localFailed
    }
}

public enum RankedLocationSuggestion: Equatable, Sendable {
    case junction(HighwayJunction)
    case google(PlacePrediction)
    case freeText(String)
}

public func rankLocationSuggestions(
    junctions: [HighwayJunction],
    predictions: [PlacePrediction],
    freeText: String,
    allowFreeText: Bool
) -> [RankedLocationSuggestion] {
    var ranked: [RankedLocationSuggestion] = junctions.map { .junction($0) }
    ranked += predictions.map { .google($0) }
    let trimmed = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
    if allowFreeText, !trimmed.isEmpty {
        ranked.append(.freeText(trimmed))
    }
    return ranked
}

public func searchLocationSuggestionsCombined(
    localQuery: String,
    googleQuery: String,
    sessionToken: String,
    searchJunctions: (String) async throws -> [HighwayJunction],
    searchPlaces: (String, String) async -> PlacesSearchResult
) async -> CombinedSearchResult {
    async let junctionTask: Result<[HighwayJunction], Error> = {
        do { return .success(try await searchJunctions(localQuery)) }
        catch { return .failure(error) }
    }()
    async let placesTask = searchPlaces(googleQuery, sessionToken)
    let junctionResult = await junctionTask
    let places = await placesTask
    switch junctionResult {
    case .success(let junctions):
        return CombinedSearchResult(junctions: junctions, places: places, localFailed: false)
    case .failure:
        return CombinedSearchResult(junctions: [], places: places, localFailed: true)
    }
}

import Foundation
import YahpazDomain

enum GooglePlaces {
    static func hasApiKey() -> Bool {
        !AppConfig.googleMapsApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func newSessionToken() -> String {
        UUID().uuidString
    }

    static func fetchPredictions(
        query: String,
        sessionToken: String
    ) async -> PlacesSearchResult {
        let key = AppConfig.googleMapsApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { return .failed("missing_key") }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .ok([]) }

        var request = URLRequest(url: URL(string: "https://places.googleapis.com/v1/places:autocomplete")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(
            "suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )
        request.setValue(AppConfig.googleMapsReferer, forHTTPHeaderField: "Referer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "input": trimmed,
            "languageCode": "he",
            "regionCode": "IL",
            "includedRegionCodes": ["il"],
            "sessionToken": sessionToken,
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .failed("http_\((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
            let decoded = try JSONDecoder().decode(AutocompleteResponse.self, from: data)
            let predictions = (decoded.suggestions ?? []).compactMap { suggestion -> PlacePrediction? in
                guard let place = suggestion.placePrediction, let placeId = place.placeId, !placeId.isEmpty else {
                    return nil
                }
                let primary = place.structuredFormat?.mainText?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? place.text?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? placeId
                let secondary = place.structuredFormat?.secondaryText?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return PlacePrediction(placeId: placeId, primaryText: primary, secondaryText: secondary)
            }
            return .ok(predictions)
        } catch {
            return .failed("network")
        }
    }

    static func fetchDetails(
        placeId: String,
        sessionToken: String
    ) async -> PlaceDetails? {
        let key = AppConfig.googleMapsApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty { return nil }
        let id = placeId.hasPrefix("places/") ? String(placeId.dropFirst("places/".count)) : placeId
        var components = URLComponents(string: "https://places.googleapis.com/v1/places/\(id)")!
        components.queryItems = [
            URLQueryItem(name: "sessionToken", value: sessionToken),
            URLQueryItem(name: "languageCode", value: "he"),
            URLQueryItem(name: "regionCode", value: "IL"),
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("id,displayName,formattedAddress,location", forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue(AppConfig.googleMapsReferer, forHTTPHeaderField: "Referer")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(PlaceDetailsResponse.self, from: data)
            guard let lat = decoded.location?.latitude, let lng = decoded.location?.longitude else {
                return nil
            }
            let rawId = decoded.id ?? id
            let cleanId = rawId.hasPrefix("places/") ? String(rawId.dropFirst("places/".count)) : rawId
            return PlaceDetails(
                placeId: cleanId,
                label: formatPlaceLabel(
                    displayName: decoded.displayName?.text,
                    formattedAddress: decoded.formattedAddress,
                    fallback: cleanId
                ),
                lat: lat,
                lng: lng
            )
        } catch {
            return nil
        }
    }

    struct PlaceDetails: Equatable, Sendable {
        var placeId: String
        var label: String
        var lat: Double
        var lng: Double
    }
}

func formatPlaceLabel(displayName: String?, formattedAddress: String?, fallback: String) -> String {
    let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let address = formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !address.isEmpty && !name.isEmpty {
        if address == name || address.hasPrefix("\(name),") || address.contains(", \(name),") {
            return address
        }
        if !address.contains(name) {
            return "\(name), \(address)"
        }
        return address
    }
    return address.isEmpty ? (name.isEmpty ? fallback : name) : address
}

private struct AutocompleteResponse: Decodable {
    var suggestions: [Suggestion]?

    struct Suggestion: Decodable {
        var placePrediction: PlacePredictionPayload?
    }

    struct PlacePredictionPayload: Decodable {
        var placeId: String?
        var text: TextValue?
        var structuredFormat: StructuredFormat?
    }

    struct StructuredFormat: Decodable {
        var mainText: TextValue?
        var secondaryText: TextValue?
    }

    struct TextValue: Decodable {
        var text: String?
    }
}

private struct PlaceDetailsResponse: Decodable {
    var id: String?
    var displayName: TextValue?
    var formattedAddress: String?
    var location: Coordinate?

    struct TextValue: Decodable {
        var text: String?
    }

    struct Coordinate: Decodable {
        var latitude: Double?
        var longitude: Double?
    }
}

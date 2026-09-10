import Foundation

public let JUNCTION_PLACE_ID_PREFIX = "junction:"
public let JUNCTION_RESULT_LIMIT = 15

public struct HighwayJunction: Equatable, Sendable, Codable {
    public var id: String
    public var nameHe: String
    public var nameEn: String?
    public var roads: String?
    public var lat: Double
    public var lng: Double

    public init(
        id: String,
        nameHe: String,
        nameEn: String? = nil,
        roads: String? = nil,
        lat: Double,
        lng: Double
    ) {
        self.id = id
        self.nameHe = nameHe
        self.nameEn = nameEn
        self.roads = roads
        self.lat = lat
        self.lng = lng
    }

    enum CodingKeys: String, CodingKey {
        case id
        case nameHe = "name_he"
        case nameEn = "name_en"
        case roads, lat, lng
    }
}

public struct HighwayJunctionCatalogRow: Equatable, Sendable, Codable {
    public var id: String
    public var nameHe: String
    public var nameEn: String?
    public var roads: String?
    public var lat: Double
    public var lng: Double
    public var aliasesHe: [String]
    public var aliasesEn: [String]

    public init(
        id: String,
        nameHe: String,
        nameEn: String? = nil,
        roads: String? = nil,
        lat: Double,
        lng: Double,
        aliasesHe: [String] = [],
        aliasesEn: [String] = []
    ) {
        self.id = id
        self.nameHe = nameHe
        self.nameEn = nameEn
        self.roads = roads
        self.lat = lat
        self.lng = lng
        self.aliasesHe = aliasesHe
        self.aliasesEn = aliasesEn
    }

    enum CodingKeys: String, CodingKey {
        case id
        case nameHe = "name_he"
        case nameEn = "name_en"
        case roads, lat, lng
        case aliasesHe = "aliases_he"
        case aliasesEn = "aliases_en"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nameHe = try c.decode(String.self, forKey: .nameHe)
        nameEn = try c.decodeIfPresent(String.self, forKey: .nameEn)
        roads = try c.decodeIfPresent(String.self, forKey: .roads)
        lat = try c.decode(Double.self, forKey: .lat)
        lng = try c.decode(Double.self, forKey: .lng)
        aliasesHe = try c.decodeIfPresent([String].self, forKey: .aliasesHe) ?? []
        aliasesEn = try c.decodeIfPresent([String].self, forKey: .aliasesEn) ?? []
    }

    public var asJunction: HighwayJunction {
        HighwayJunction(id: id, nameHe: nameHe, nameEn: nameEn, roads: roads, lat: lat, lng: lng)
    }
}

public struct JunctionQueryParts: Equatable, Sendable {
    public var baseQuery: String
    public var directionSuffix: String?

    public init(baseQuery: String, directionSuffix: String? = nil) {
        self.baseQuery = baseQuery
        self.directionSuffix = directionSuffix
    }
}

public func junctionPlaceId(_ id: String) -> String {
    JUNCTION_PLACE_ID_PREFIX + id
}

public func junctionIdFromPlaceId(_ placeId: String?) -> String? {
    guard let placeId, placeId.hasPrefix(JUNCTION_PLACE_ID_PREFIX) else { return nil }
    return String(placeId.dropFirst(JUNCTION_PLACE_ID_PREFIX.count))
}

func normalizedRoadNumber(_ value: String) -> String? {
    let withoutParens = value.replacingOccurrences(
        of: #"\([^)]*\)"#,
        with: "",
        options: .regularExpression
    ).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let match = roadNumberRegex.firstMatch(
        in: withoutParens,
        range: NSRange(withoutParens.startIndex..., in: withoutParens)
    ), let numRange = Range(match.range(at: 1), in: withoutParens) else {
        return nil
    }
    return String(withoutParens[numRange])
}

/// First numeric junction-road token, accepting "4", "כביש 4", and "כביש4".
public func firstJunctionRoadNumber(_ roads: String?) -> String? {
    guard let roads else { return nil }
    for token in roads.split(separator: "/", omittingEmptySubsequences: false) {
        if let roadNumber = normalizedRoadNumber(String(token)) {
            return roadNumber
        }
    }
    return nil
}

/// Accept closed-list labels such as "6" or "כביש 6", but no partial number matches.
public func roadNumberFromLookupName(_ name: String) -> String? {
    normalizedRoadNumber(name)
}

/// Try numeric slash-delimited tokens in order and resolve the first unique exact match.
public func matchingRoadIdForJunction(_ roads: String?, lookups: [LookupOption]) -> String? {
    guard let roads else { return nil }
    for token in roads.split(separator: "/", omittingEmptySubsequences: false) {
        guard let junctionRoadNumber = normalizedRoadNumber(String(token)) else { continue }
        let matches = lookups.filter { roadNumberFromLookupName($0.name) == junctionRoadNumber }
        if matches.count == 1 { return matches[0].id }
    }
    return nil
}

/// A junction is the source of truth: overwrite with a match, otherwise preserve the road.
public func roadIdAfterJunctionSelection(
    currentRoadId: String,
    junctionRoads: String?,
    lookups: [LookupOption]
) -> String {
    matchingRoadIdForJunction(junctionRoads, lookups: lookups) ?? currentRoadId
}

public func splitJunctionDirection(_ query: String) -> JunctionQueryParts {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let range = NSRange(trimmed.startIndex..., in: trimmed)
    guard let match = trailingDirectionRegex.firstMatch(in: trimmed, range: range),
          match.numberOfRanges >= 2,
          let fullRange = Range(match.range(at: 0), in: trimmed),
          let suffixRange = Range(match.range(at: 1), in: trimmed)
    else {
        return JunctionQueryParts(baseQuery: trimmed)
    }
    return JunctionQueryParts(
        baseQuery: trimmed[..<fullRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines),
        directionSuffix: String(trimmed[suffixRange])
    )
}

func normalizeJunctionText(_ value: String) -> String {
    let nfd = value.decomposedStringWithCanonicalMapping
    let noNikud = String(nfd.unicodeScalars.filter { !hebrewNikud.contains($0.value) })
    let lowered = noNikud.lowercased(with: Locale(identifier: "he"))
    let replaced = lowered.unicodeScalars.map { scalar -> Character in
        junctionPunctuation.contains(scalar) ? " " : Character(scalar)
    }
    return String(replaced)
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
}

func searchVariants(_ value: String) -> [String] {
    let normalized = normalizeJunctionText(value)
    let range = NSRange(normalized.startIndex..., in: normalized)
    let withoutKind: String
    if let match = junctionKindPrefixRegex.firstMatch(in: normalized, range: range),
       let matched = Range(match.range, in: normalized)
    {
        withoutKind = String(normalized[matched.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
        withoutKind = normalized
    }
    if !withoutKind.isEmpty, withoutKind != normalized {
        return [normalized, withoutKind]
    }
    return [normalized]
}

/// Damerau-Levenshtein distance, including one adjacent transposition.
public func junctionEditDistance(_ left: String, _ right: String) -> Int {
    let leftChars = Array(left)
    let rightChars = Array(right)
    let rows = leftChars.count + 1
    let columns = rightChars.count + 1
    var matrix = Array(repeating: Array(repeating: 0, count: columns), count: rows)
    for row in 0..<rows { matrix[row][0] = row }
    for column in 0..<columns { matrix[0][column] = column }

    if leftChars.isEmpty { return rightChars.count }
    if rightChars.isEmpty { return leftChars.count }

    for row in 1..<rows {
        for column in 1..<columns {
            let substitutionCost = leftChars[row - 1] == rightChars[column - 1] ? 0 : 1
            matrix[row][column] = min(
                matrix[row - 1][column] + 1,
                matrix[row][column - 1] + 1,
                matrix[row - 1][column - 1] + substitutionCost
            )
            if row > 1,
               column > 1,
               leftChars[row - 1] == rightChars[column - 2],
               leftChars[row - 2] == rightChars[column - 1]
            {
                matrix[row][column] = min(matrix[row][column], matrix[row - 2][column - 2] + 1)
            }
        }
    }
    return matrix[leftChars.count][rightChars.count]
}

func matchScore(term: String, query: String) -> Int? {
    if term.isEmpty || query.isEmpty { return nil }
    if term == query { return 0 }
    if term.hasPrefix(query) { return 10 + min(term.count - query.count, 9) }
    if let index = term.range(of: query)?.lowerBound {
        return 20 + min(term.distance(from: term.startIndex, to: index), 9)
    }
    if query.count < 4 { return nil }
    let distance = junctionEditDistance(term, query)
    let maxDistance = max(1, query.count / 4)
    return distance <= maxDistance ? 40 + distance : nil
}

public func rankHighwayJunctions(
    _ rows: [HighwayJunctionCatalogRow],
    query: String
) -> [HighwayJunction] {
    let parts = splitJunctionDirection(query)
    let queryVariants = Array(Set(searchVariants(query) + searchVariants(parts.baseQuery)))
        .filter { !$0.isEmpty }

    return rows
        .compactMap { row -> (HighwayJunctionCatalogRow, Int)? in
            let terms = ([row.nameHe, row.nameEn].compactMap { $0 } + row.aliasesHe + row.aliasesEn)
                .flatMap(searchVariants)
            let scores = terms.flatMap { term in
                queryVariants.compactMap { matchScore(term: term, query: $0) }
            }
            guard let score = scores.min() else { return nil }
            return (row, score)
        }
        .sorted { left, right in
            if left.1 != right.1 { return left.1 < right.1 }
            return left.0.nameHe.localizedCompare(right.0.nameHe) == .orderedAscending
        }
        .prefix(JUNCTION_RESULT_LIMIT)
        .map(\.0.asJunction)
}

public func junctionLocationLabel(junctionName: String, typedQuery: String) -> String {
    let suffix = splitJunctionDirection(typedQuery).directionSuffix
    guard let suffix else { return junctionName }
    if normalizeJunctionText(junctionName) == normalizeJunctionText(typedQuery) {
        return junctionName
    }
    return "\(junctionName) \(suffix)"
}

/// Google query: road number first, then the free-text location.
public func eventGeocodeQuery(road: String?, location: String?) -> String? {
    let roadName = road?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let place = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let number = roadName.isEmpty ? nil : roadNumberForGeocode(roadName)
    let roadPart = number.map { "כביש \($0)" } ?? roadName
    if roadPart.isEmpty && place.isEmpty { return nil }
    if roadPart.isEmpty { return place }
    if place.isEmpty { return roadPart }
    if place.contains(roadPart) || place.contains(roadName) { return place }
    return "\(roadPart) \(place)"
}

func roadNumberForGeocode(_ roadName: String) -> String? {
    if let match = parenNumberRegex.firstMatch(
        in: roadName,
        range: NSRange(roadName.startIndex..., in: roadName)
    ), let range = Range(match.range(at: 1), in: roadName) {
        return String(roadName[range])
    }
    if let match = firstDigitsRegex.firstMatch(
        in: roadName,
        range: NSRange(roadName.startIndex..., in: roadName)
    ), let range = Range(match.range, in: roadName) {
        return String(roadName[range])
    }
    return nil
}

private let hebrewNikud: ClosedRange<UInt32> = 0x0591...0x05C7

private let junctionPunctuation = CharacterSet(charactersIn: "\"'׳״.,()[]{}-–—")

private let trailingDirectionRegex = try! NSRegularExpression(
    pattern: #"\s+((?:(?:ל|ב)כיוון\s+(?:ה?(?:מערב|מזרח|צפון|דרום)|ל(?:מערב|מזרח|צפון|דרום)))|(?:ל?(?:מערב|מזרח|צפון|דרום)|מערבה|מזרחה|צפונה|דרומה))$"#
)

private let junctionKindPrefixRegex = try! NSRegularExpression(pattern: #"^(?:צומת|מחלף)\s+"#)

private let roadNumberRegex = try! NSRegularExpression(pattern: #"^(?:כביש\s*)?(\d+)$"#)

private let parenNumberRegex = try! NSRegularExpression(pattern: #"\((\d+)\)"#)

private let firstDigitsRegex = try! NSRegularExpression(pattern: #"\d+"#)

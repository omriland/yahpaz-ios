import Foundation

public let PLATE_LOOKUP_RESOURCE_ID = "053cea08-09bc-40ec-8f7a-156f0677aff3"

public struct PlateLookupHit: Equatable, Sendable {
    public var model: String?
    public var color: String?
    public var manufacturer: String?

    public init(model: String?, color: String?, manufacturer: String? = nil) {
        self.model = model
        self.color = color
        self.manufacturer = manufacturer
    }
}

/// Strips non-digits then parses as Int (leading zeros drop via Int).
public func plateLookupMispar(_ plate: String) -> Int {
    let digits = plate.filter(\.isNumber)
    return Int(digits) ?? 0
}

public func plateLookupUrl(plate: String) -> String {
    let filters = #"{"mispar_rechev":\#(plateLookupMispar(plate))}"#
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
    let encodedFilters = filters.addingPercentEncoding(withAllowedCharacters: allowed) ?? filters
    return "https://data.gov.il/api/3/action/datastore_search?"
        + "resource_id=\(PLATE_LOOKUP_RESOURCE_ID)"
        + "&filters=\(encodedFilters)"
        + "&fields=tzeva_rechev,kinuy_mishari,tozeret_nm"
        + "&limit=1"
}

public func parsePlateLookupBody(_ body: String) -> PlateLookupHit? {
    let trimmedStart = body.drop(while: { $0.isWhitespace })
    guard trimmedStart.hasPrefix("{") else { return nil }
    guard let data = body.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let result = root["result"] as? [String: Any],
          let records = result["records"] as? [[String: Any]],
          let row = records.first
    else { return nil }
    let modelRaw = (row["kinuy_mishari"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let colorRaw = (row["tzeva_rechev"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let manufacturerRaw = (row["tozeret_nm"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return PlateLookupHit(
        model: modelRaw.isEmpty ? nil : modelRaw,
        color: colorRaw.isEmpty ? nil : colorRaw,
        manufacturer: manufacturerRaw.isEmpty ? nil : manufacturerRaw
    )
}

public func lookupPlate(plate: String) async -> PlateLookupHit? {
    guard let url = URL(string: plateLookupUrl(plate: plate)) else { return nil }
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        let body = String(data: data, encoding: .utf8) ?? ""
        return parsePlateLookupBody(body)
    } catch {
        return nil
    }
}

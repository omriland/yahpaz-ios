import Foundation

/// Hebrew (and Latin) manufacturer → car-logos-dataset slug. Longest keys first.

private let countrySuffixes = [
    "גרמניה",
    "גרמנ",
    "ד.קור",
    "דקור",
    "קוריאה",
    "יפן",
    "סין",
    "צרפת",
    "איטליה",
    "אנגליה",
    "בריטניה",
    "ארהב",
    "ארה\"ב",
    "ארצות הברית",
    "צכיה",
    "צ׳כיה",
    "ספרד",
    "שבדיה",
    "שוודיה",
    "הודו",
    "תאילנד",
    "מקסיקו",
    "טורקיה",
    "רומניה",
    "סלובקיה",
]

/// Longest-first Hebrew / mixed keys.
private let hebrewBrands: [(String, String)] = [
    ("אלפא רומיאו", "alfa-romeo"),
    ("לנד רובר", "land-rover"),
    ("מרצדס בנץ", "mercedes-benz"),
    ("מרצדס", "mercedes-benz"),
    ("פולקסווגן", "volkswagen"),
    ("סאנגיונג", "ssangyong"),
    ("מיצובישי", "mitsubishi"),
    ("שברולט", "chevrolet"),
    ("סיטרואן", "citroen"),
    ("פיג׳ו", "peugeot"),
    ("פיג'ו", "peugeot"),
    ("רנו", "renault"),
    ("טויוטה", "toyota"),
    ("יונדאי", "hyundai"),
    ("ג׳נסיס", "genesis"),
    ("ג'נסיס", "genesis"),
    ("לקסוס", "lexus"),
    ("אינפיניטי", "infiniti"),
    ("סובארו", "subaru"),
    ("הונדה", "honda"),
    ("ניסאן", "nissan"),
    ("מאזדה", "mazda"),
    ("סוזוקי", "suzuki"),
    ("איסוזו", "isuzu"),
    ("סקודה", "skoda"),
    ("סיאט", "seat"),
    ("קופרה", "cupra"),
    ("אאודי", "audi"),
    ("פורשה", "porsche"),
    ("וולוו", "volvo"),
    ("יגואר", "jaguar"),
    ("פיאט", "fiat"),
    ("אופל", "opel"),
    ("פורד", "ford"),
    ("דאצ׳יה", "dacia"),
    ("דאצ'יה", "dacia"),
    ("טסלה", "tesla"),
    ("קרייזלר", "chrysler"),
    ("דודג׳", "dodge"),
    ("דודג'", "dodge"),
    ("ג׳יפ", "jeep"),
    ("ג'יפ", "jeep"),
    ("ג׳ילי", "geely"),
    ("ג'ילי", "geely"),
    ("צ׳רי", "chery"),
    ("צ'רי", "chery"),
    ("צרי", "chery"),
    ("בי.ווי.די", "byd"),
    ("ביווידי", "byd"),
    ("סמארט", "smart"),
    ("מיני", "mini"),
    ("אקורה", "acura"),
    ("לינקולן", "lincoln"),
    ("קדילאק", "cadillac"),
    ("קיה", "kia"),
    ("ב מ וו", "bmw"),
    ("ב.מ.וו", "bmw"),
    ("במוו", "bmw"),
]

private let latinBrands: [(String, String)] = [
    ("mercedes-benz", "mercedes-benz"),
    ("mercedes", "mercedes-benz"),
    ("volkswagen", "volkswagen"),
    ("ssangyong", "ssangyong"),
    ("mitsubishi", "mitsubishi"),
    ("chevrolet", "chevrolet"),
    ("land rover", "land-rover"),
    ("land-rover", "land-rover"),
    ("alfa romeo", "alfa-romeo"),
    ("alfa-romeo", "alfa-romeo"),
    ("citroen", "citroen"),
    ("citroën", "citroen"),
    ("peugeot", "peugeot"),
    ("renault", "renault"),
    ("toyota", "toyota"),
    ("hyundai", "hyundai"),
    ("genesis", "genesis"),
    ("lexus", "lexus"),
    ("infiniti", "infiniti"),
    ("subaru", "subaru"),
    ("honda", "honda"),
    ("nissan", "nissan"),
    ("mazda", "mazda"),
    ("suzuki", "suzuki"),
    ("isuzu", "isuzu"),
    ("skoda", "skoda"),
    ("škoda", "skoda"),
    ("seat", "seat"),
    ("cupra", "cupra"),
    ("audi", "audi"),
    ("porsche", "porsche"),
    ("volvo", "volvo"),
    ("jaguar", "jaguar"),
    ("fiat", "fiat"),
    ("opel", "opel"),
    ("ford", "ford"),
    ("dacia", "dacia"),
    ("tesla", "tesla"),
    ("chrysler", "chrysler"),
    ("dodge", "dodge"),
    ("jeep", "jeep"),
    ("geely", "geely"),
    ("chery", "chery"),
    ("byd", "byd"),
    ("smart", "smart"),
    ("mini", "mini"),
    ("acura", "acura"),
    ("lincoln", "lincoln"),
    ("cadillac", "cadillac"),
    ("kia", "kia"),
    ("bmw", "bmw"),
    ("mg", "mg"),
]

public func normalizeManufacturer(_ raw: String) -> String {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    if value.isEmpty { return "" }
    var changed = true
    while changed {
        changed = false
        for suffix in countrySuffixes {
            let withDot = "\(suffix)."
            if value == suffix || value == withDot {
                value = ""
                changed = true
            } else if value.hasSuffix(" \(withDot)") {
                value = String(value.dropLast(" \(withDot)".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                changed = true
            } else if value.hasSuffix(" \(suffix)") {
                value = String(value.dropLast(" \(suffix)".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                changed = true
            }
        }
    }
    return value.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

public func resolveCarLogoSlug(_ manufacturer: String?) -> String? {
    let normalized = normalizeManufacturer(manufacturer ?? "")
    if normalized.isEmpty { return nil }

    for (key, slug) in hebrewBrands {
        if normalized.contains(key) { return slug }
    }

    let lower = normalized.lowercased()
    for (key, slug) in latinBrands {
        if lower.contains(key) { return slug }
    }

    return nil
}

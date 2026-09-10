import Foundation

/** OCR confuses these glyphs with digits on Israeli plates. */
private let OCR_DIGIT_MAP: [Character: Character] = [
    "O": "0",
    "o": "0",
    "D": "0",
    "Q": "0",
    "I": "1",
    "l": "1",
    "|": "1",
    "!": "1",
    "Z": "2",
    "z": "2",
    "S": "5",
    "s": "5",
    "B": "8",
    "G": "6",
]

/**
 Normalize one OCR line into digit-ish characters, keeping separators so
 grouped plate patterns (12-345-67) stay recoverable.
 */
public func normalizePlateOcrLine(_ raw: String) -> String {
    var out = ""
    out.reserveCapacity(raw.count)
    for ch in raw {
        if ch.isNumber {
            out.append(ch)
        } else if let mapped = OCR_DIGIT_MAP[ch] {
            out.append(mapped)
        } else if ch == "-" || ch == " " || ch == "·" || ch == "." || ch == ":" || ch == "/" {
            out.append("-")
        }
    }
    return out
}

private let plateCandidateRegex = try! NSRegularExpression(pattern: #"\d(?:[\d-]{5,10})\d"#)

/**
 Extract unique 7- or 8-digit Israeli plate candidates from OCR text.
 Prefers longer (8-digit) matches when overlapping, returns most-likely-first.
 */
public func extractIsraeliPlateCandidates(_ ocrText: String) -> [String] {
    if ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
    var scored: [String: Int] = [:]
    var order: [String] = []

    func bump(_ digits: String, score: Int) {
        if let existing = scored[digits] {
            scored[digits] = max(existing, score)
        } else {
            scored[digits] = score
            order.append(digits)
        }
    }

    for line in ocrText.split(separator: "\n", omittingEmptySubsequences: false) {
        let normalized = normalizePlateOcrLine(String(line))
        if normalized.isEmpty { continue }
        let ns = normalized as NSString
        let range = NSRange(location: 0, length: ns.length)
        for match in plateCandidateRegex.matches(in: normalized, range: range) {
            let value = ns.substring(with: match.range)
            let digits = value.filter(\.isNumber)
            if digits.count != 7 && digits.count != 8 { continue }
            let score: Int
            if value.contains("-") {
                score = 3
            } else if digits.count == 8 {
                score = 2
            } else {
                score = 1
            }
            bump(digits, score: score)
        }
        for run in normalized.split(separator: "-") {
            switch run.count {
            case 7: bump(String(run), score: 1)
            case 8: bump(String(run), score: 2)
            default: break
            }
        }
        let pure = normalized.filter(\.isNumber)
        switch pure.count {
        case 7: bump(pure, score: 1)
        case 8: bump(pure, score: 2)
        default: break
        }
    }

    return scored
        .sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key.count > rhs.key.count
        }
        .map(\.key)
}

public struct PlateScanConfirmState: Equatable, Sendable {
    public var digits: String?
    public var streak: Int

    public init(digits: String? = nil, streak: Int = 0) {
        self.digits = digits
        self.streak = streak
    }
}

/**
 Require `requiredStreak` consecutive frames with the same top candidate
 before treating a plate as confirmed (reduces OCR flicker).
 */
public func advancePlateScanConfirm(
    _ state: PlateScanConfirmState,
    topCandidate: String?,
    requiredStreak: Int = 3
) -> (state: PlateScanConfirmState, confirmed: String?) {
    let next = plateDigits(topCandidate ?? "")
    if next.count != 7 && next.count != 8 {
        return (PlateScanConfirmState(), nil)
    }
    let streak = state.digits == next ? state.streak + 1 : 1
    let updated = PlateScanConfirmState(digits: next, streak: streak)
    if streak >= requiredStreak {
        return (updated, next)
    }
    return (updated, nil)
}

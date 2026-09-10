import CryptoKit
import Foundation

public let PRIVACY_PATH = "/privacy"
public let PRIVACY_TOKEN_TTL_SEC = 15 * 60
public let PRIVACY_TOKEN_PURPOSE = "privacy-v1"
private let CLOCK_SKEW_SEC: Int64 = 60

public func createPrivacyPageToken(
    secret: String,
    nowSec: Int64,
    ttlSec: Int = PRIVACY_TOKEN_TTL_SEC
) -> String {
    let exp = nowSec + Int64(ttlSec)
    let sig = hmacSha256Hex(secret: secret, message: "\(PRIVACY_TOKEN_PURPOSE).\(exp)")
    return "\(exp).\(sig)"
}

public func verifyPrivacyPageToken(
    secret: String,
    token: String,
    nowSec: Int64,
    ttlSec: Int = PRIVACY_TOKEN_TTL_SEC
) -> Bool {
    guard let parsed = parsePrivacyToken(token) else { return false }
    if nowSec > parsed.exp + CLOCK_SKEW_SEC { return false }
    if parsed.exp > nowSec + Int64(ttlSec) + CLOCK_SKEW_SEC { return false }
    let expected = hmacSha256Hex(secret: secret, message: "\(PRIVACY_TOKEN_PURPOSE).\(parsed.exp)")
    return timingSafeEqualHex(parsed.sig, expected)
}

public func buildPrivacyPolicyUrl(origin: String, token: String) -> String {
    let base = origin.hasSuffix("/") ? String(origin.dropLast()) : origin
    return "\(base)\(PRIVACY_PATH)?t=\(token)"
}

private struct PrivacyTokenParts {
    var exp: Int64
    var sig: String
}

private func parsePrivacyToken(_ token: String) -> PrivacyTokenParts? {
    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let dot = trimmed.firstIndex(of: "."),
          dot > trimmed.startIndex,
          trimmed.index(after: dot) < trimmed.endIndex
    else { return nil }
    let expRaw = String(trimmed[..<dot])
    let sig = String(trimmed[trimmed.index(after: dot)...]).lowercased()
    guard expRaw.range(of: #"^\d{10,12}$"#, options: .regularExpression) != nil else { return nil }
    guard sig.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil else { return nil }
    guard let exp = Int64(expRaw) else { return nil }
    return PrivacyTokenParts(exp: exp, sig: sig)
}

private func hmacSha256Hex(secret: String, message: String) -> String {
    let key = SymmetricKey(data: Data(secret.utf8))
    let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
    return mac.map { String(format: "%02x", $0) }.joined()
}

private func timingSafeEqualHex(_ left: String, _ right: String) -> Bool {
    guard left.count == right.count else { return false }
    var diff = 0
    for (lhs, rhs) in zip(left.unicodeScalars, right.unicodeScalars) {
        diff |= Int(lhs.value) ^ Int(rhs.value)
    }
    return diff == 0
}

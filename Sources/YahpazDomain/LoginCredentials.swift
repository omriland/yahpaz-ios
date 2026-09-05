import Foundation

/// Login fields are Latin (email / password). An RTL text field can inject
/// bidi marks into the stored value so GoTrue sees a different string than web.
private let loginInvisible = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}\u{FEFF}")

public func normalizeLoginEmail(_ raw: String) -> String {
    stripLoginInvisible(raw).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

public func normalizeLoginSecret(_ raw: String) -> String {
    stripLoginInvisible(raw)
}

private func stripLoginInvisible(_ raw: String) -> String {
    String(raw.unicodeScalars.filter { !loginInvisible.contains($0) })
}

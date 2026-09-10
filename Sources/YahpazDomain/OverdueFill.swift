import Foundation

public let OVERDUE_48H_MS: Int64 = 48 * 60 * 60 * 1000
public let OVERDUE_FILL_CARD_TIP = "אירוע ממתין לתיעוד מעל ל־48 שעות"

public func isMineFillOverdue(
    isCancelled: Bool,
    participationStatus: ParticipationStatus?,
    fillCompletableAt: String?,
    nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
) -> Bool {
    if isCancelled { return false }
    if participationStatus == nil || participationStatus == .done { return false }
    guard let start = parseInstantMs(fillCompletableAt) else { return false }
    return nowMs - start >= OVERDUE_48H_MS
}

private func parseInstantMs(_ value: String?) -> Int64? {
    let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if raw.isEmpty { return nil }
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let withoutFraction = ISO8601DateFormatter()
    withoutFraction.formatOptions = [.withInternetDateTime]
    guard let date = withFraction.date(from: raw) ?? withoutFraction.date(from: raw) else {
        return nil
    }
    return Int64((date.timeIntervalSince1970 * 1000).rounded())
}

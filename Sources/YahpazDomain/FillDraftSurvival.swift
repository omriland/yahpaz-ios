import Foundation

public let FILL_DRAFT_STASH_SCOPE = "responder"

/** Anything older than this is stale enough that restoring it would confuse. */
public let FILL_DRAFT_MAX_AGE_MS: Int64 = 1000 * 60 * 60 * 24 * 14

public enum FillBackAction: String, Equatable, Sendable {
    case dropUnfinishedPhoto
    case showDocs
    case leave
}

public func fillDraftKey(scope: String, id: String) -> String {
    "yahpaz.fillDraft.\(scope).\(id)"
}

public func shouldKeepLiveFormBoot(loadState: String, hasTypedDraft: Bool) -> Bool {
    if loadState != "ready" { return false }
    return hasTypedDraft
}

public func isFillDraftStashFresh(savedAt: Int64, now: Int64) -> Bool {
    now - savedAt <= FILL_DRAFT_MAX_AGE_MS
}

public func shouldPreferStashedFillDraft(
    stashed: ResponderFillDraft?,
    savedAt: Int64?,
    server: ResponderFillDraft,
    now: Int64
) -> Bool {
    guard let stashed, let savedAt else { return false }
    if !isFillDraftStashFresh(savedAt: savedAt, now: now) { return false }
    return stashed != server
}

public func decideFillBack(onMediaPane: Bool, unfinishedMediaDraftCount: Int) -> FillBackAction {
    if unfinishedMediaDraftCount > 0 { return .dropUnfinishedPhoto }
    if onMediaPane { return .showDocs }
    return .leave
}

/** `HH:mm` in the viewer's own clock, for the "saved at" caption. */
public func fillDraftSavedLabel(savedAtMillis: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(savedAtMillis) / 1000)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "he_IL")
    formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

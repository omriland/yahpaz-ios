import Foundation

public let FEEDBACK_BODY_MAX = 2000
public let FEEDBACK_AUDIO_MAX_BYTES = 5 * 1024 * 1024
public let FEEDBACK_RECORD_MAX_SECONDS = 90
public let FEEDBACK_ATTACH_MAX = 3
public let FEEDBACK_IMAGE_MAX_BYTES = 5 * 1024 * 1024
public let FEEDBACK_VIDEO_MAX_BYTES = 25 * 1024 * 1024
public let FEEDBACK_ATTACH_NAME_MAX = 200
public let FEEDBACK_NETWORK = "השליחה נכשלה. בדקו את החיבור ונסו שוב."
public let FEEDBACK_EMPTY_ERROR = "יש לכתוב הערה או להקליט הודעה."
public let FEEDBACK_BODY_ERROR = "ההערה ארוכה מדי. קצרו ל־2,000 תווים."
public let FEEDBACK_KIND_ERROR = "בחרו אם זה באג או הצעה."
public let FEEDBACK_AUDIO_SIZE_ERROR = "ההקלטה ארוכה מדי. הקליטו שוב בקצרה."
public let FEEDBACK_MIC_ERROR = "אין גישה למיקרופון. אפשר לכתוב הערה במקום."
public let FEEDBACK_ATTACH_HINT =
    "אפשר לצרף עד 3 קבצים: צילומי מסך עד 5 מ״ב, או סרטונים קצרים עד 25 מ״ב."
public let FEEDBACK_ATTACH_COUNT_ERROR = "אפשר לצרף עד 3 קבצים."
public let FEEDBACK_ATTACH_TYPE_ERROR = "אפשר לצרף רק צילומי מסך או סרטונים קצרים."
public let FEEDBACK_ATTACH_IMAGE_SIZE_ERROR = "התמונה גדולה מדי. בחרו קובץ עד 5 מ״ב."
public let FEEDBACK_ATTACH_VIDEO_SIZE_ERROR = "הסרטון גדול מדי. בחרו קובץ עד 25 מ״ב."
public let FEEDBACK_ATTACH_UNAVAILABLE =
    "צירוף הקבצים אינו זמין כרגע. שלחו בלי קבצים, או נסו שוב מאוחר יותר."
public let FEEDBACK_ATTACH_ADD = "צירוף קובץ"
public let FEEDBACK_SENT = "המשוב נשלח. תודה."
public let FEEDBACK_HIDE_UNTIL_REFRESH = "הסתרה עד הרענון הבא"
public let FEEDBACK_LABEL = "משוב"
public let FEEDBACK_KIND_BUG = "באג"
public let FEEDBACK_KIND_SUGGESTION = "הצעה"

public struct FeedbackPickedMeta: Equatable, Sendable {
    public var name: String
    public var mime: String
    public var size: Int

    public init(name: String, mime: String, size: Int) {
        self.name = name
        self.mime = mime
        self.size = size
    }
}

public struct FeedbackAttachResult: Equatable, Sendable {
    public var files: [FeedbackPickedMeta]
    public var error: String?

    public init(files: [FeedbackPickedMeta], error: String? = nil) {
        self.files = files
        self.error = error
    }
}

public func feedbackBodyError(_ body: String) -> String? {
    body.count > FEEDBACK_BODY_MAX ? FEEDBACK_BODY_ERROR : nil
}

public func feedbackSubmitError(kind: String?, body: String, hasAudio: Bool) -> String? {
    if kind != "bug" && kind != "suggestion" { return FEEDBACK_KIND_ERROR }
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    if let error = feedbackBodyError(trimmed) { return error }
    if trimmed.isEmpty && !hasAudio { return FEEDBACK_EMPTY_ERROR }
    return nil
}

public func feedbackStorageExt(_ mime: String) -> String {
    let lower = mime.lowercased()
    if lower.contains("webm") { return "webm" }
    if lower.contains("ogg") { return "ogg" }
    if lower.contains("mpeg") || lower.contains("mp3") { return "mp3" }
    if lower.contains("mp4") || lower.contains("m4a") || lower.contains("aac") { return "m4a" }
    return "m4a"
}

public func normalizeFeedbackAudioMime(_ mime: String) -> String {
    let lower = mime.lowercased()
    if lower.contains("webm") { return "audio/webm" }
    if lower.contains("ogg") { return "audio/ogg" }
    if lower.contains("mpeg") || lower.contains("mp3") { return "audio/mpeg" }
    return "audio/mp4"
}

public func feedbackStoragePath(userId: String, feedbackId: String, mime: String) -> String {
    "\(userId)/\(feedbackId).\(feedbackStorageExt(mime))"
}

private let FEEDBACK_IMAGE_MIMES: Set<String> = [
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
    "image/heic",
    "image/heif",
]

private let FEEDBACK_VIDEO_MIMES: Set<String> = [
    "video/mp4",
    "video/webm",
    "video/quicktime",
    "video/3gpp",
]

private let FEEDBACK_EXT_MIME: [String: String] = [
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
    "gif": "image/gif",
    "heic": "image/heic",
    "heif": "image/heif",
    "mp4": "video/mp4",
    "webm": "video/webm",
    "mov": "video/quicktime",
    "3gp": "video/3gpp",
]

public func normalizeFeedbackAttachmentMime(mime: String, name: String) -> String? {
    let fromMime = mime.lowercased()
        .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
        .first
        .map(String.init)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if fromMime == "image/jpg" { return "image/jpeg" }
    if FEEDBACK_IMAGE_MIMES.contains(fromMime) || FEEDBACK_VIDEO_MIMES.contains(fromMime) {
        return fromMime
    }
    let ext: String
    if let dot = name.lastIndex(of: ".") {
        ext = String(name[name.index(after: dot)...]).lowercased()
    } else {
        ext = ""
    }
    return FEEDBACK_EXT_MIME[ext]
}

public func feedbackAttachmentKind(mime: String, name: String = "") -> String? {
    guard let normalized = normalizeFeedbackAttachmentMime(mime: mime, name: name) else { return nil }
    return normalized.hasPrefix("image/") ? "image" : "video"
}

public func feedbackAttachmentExt(mime: String, name: String = "") -> String? {
    switch normalizeFeedbackAttachmentMime(mime: mime, name: name) {
    case "image/jpeg": return "jpg"
    case "image/png": return "png"
    case "image/webp": return "webp"
    case "image/gif": return "gif"
    case "image/heic": return "heic"
    case "image/heif": return "heif"
    case "video/mp4": return "mp4"
    case "video/webm": return "webm"
    case "video/quicktime": return "mov"
    case "video/3gpp": return "3gp"
    default: return nil
    }
}

public func feedbackAttachmentStoragePath(
    userId: String,
    feedbackId: String,
    attachmentId: String,
    mime: String,
    name: String = ""
) -> String? {
    guard let ext = feedbackAttachmentExt(mime: mime, name: name) else { return nil }
    return "\(userId)/\(feedbackId)/\(attachmentId).\(ext)"
}

public func feedbackAttachmentError(_ file: FeedbackPickedMeta) -> String? {
    guard let kind = feedbackAttachmentKind(mime: file.mime, name: file.name) else {
        return FEEDBACK_ATTACH_TYPE_ERROR
    }
    if kind == "image" && file.size > FEEDBACK_IMAGE_MAX_BYTES { return FEEDBACK_ATTACH_IMAGE_SIZE_ERROR }
    if kind == "video" && file.size > FEEDBACK_VIDEO_MAX_BYTES { return FEEDBACK_ATTACH_VIDEO_SIZE_ERROR }
    if file.size <= 0 { return FEEDBACK_ATTACH_TYPE_ERROR }
    return nil
}

public func addFeedbackAttachments(
    current: [FeedbackPickedMeta],
    incoming: [FeedbackPickedMeta]
) -> FeedbackAttachResult {
    var next = current
    var error: String?
    for file in incoming {
        if next.count >= FEEDBACK_ATTACH_MAX {
            error = FEEDBACK_ATTACH_COUNT_ERROR
            break
        }
        if let fileError = feedbackAttachmentError(file) {
            error = fileError
            continue
        }
        next.append(file)
    }
    return FeedbackAttachResult(files: next, error: error)
}

public func sanitizeFeedbackAttachmentName(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "/", with: "")
        .replacingOccurrences(of: "\\", with: "")
    let cleaned = trimmed.isEmpty ? "קובץ" : trimmed
    return String(cleaned.prefix(FEEDBACK_ATTACH_NAME_MAX))
}

public func isMissingFeedbackAttachmentsColumn(_ message: String?) -> Bool {
    guard let text = message else { return false }
    let lower = text.lowercased()
    guard lower.contains("attachments") else { return false }
    return text.contains("42703")
        || text.contains("PGRST204")
        || lower.contains("does not exist")
        || text.contains("Could not find")
}

public func formatRecordSeconds(_ total: Int) -> String {
    let safe = min(max(total, 0), FEEDBACK_RECORD_MAX_SECONDS)
    let minutes = safe / 60
    let seconds = safe % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

public func shouldAutoStopRecording(_ elapsedSeconds: Int) -> Bool {
    elapsedSeconds >= FEEDBACK_RECORD_MAX_SECONDS
}

public func feedbackPagePath(fillEventId: String?, tab: String, toolsDestination: String) -> String {
    if let fillEventId, !fillEventId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return "/fill/\(fillEventId)"
    }
    if toolsDestination != "HUB" {
        return "/\(toolsDestination.lowercased())"
    }
    return "/\(tab.lowercased())"
}

/// Android `shouldShowFeedbackFab` — hide on fill and event/shift forms.
public func shouldShowFeedbackFab(hiddenUntilRefresh: Bool, overlay: String, fillOpen: Bool) -> Bool {
    if hiddenUntilRefresh || fillOpen { return false }
    return overlay != "NEW_EVENT"
        && overlay != "EDIT_EVENT"
        && overlay != "NEW_SHIFT"
        && overlay != "EDIT_SHIFT"
}

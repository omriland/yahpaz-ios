import Foundation

public let EVENT_MEDIA_CAP = 20
public let EVENT_MEDIA_CAPTION_MAX = 200
public let EVENT_MEDIA_LEFTOVER_ERROR = "בחרו מתי צולמה כל תמונה."
public let EVENT_MEDIA_CAP_ERROR = "ניתן לצרף עד 20 תמונות לאירוע."
public let EVENT_MEDIA_CAPTION_ERROR = "התיאור קצר עד 200 תווים."
public let EVENT_MEDIA_BAD_TYPE = "לא ניתן להעלות קובץ זה. בחרו תמונה."
public let EVENT_MEDIA_TOO_LARGE = "הקובץ גדול מדי. בחרו תמונה אחרת."
public let EVENT_MEDIA_COMPRESS_FAIL = "לא הצלחנו לדחוס את התמונה. נסו תמונה אחרת."
public let EVENT_MEDIA_HEIC_FAIL =
    "לא הצלחנו לקרוא את התמונה. שמרו כ-JPEG או PNG ונסו שוב."
public let EVENT_MEDIA_NETWORK = "ההעלאה נכשלה. נסו שוב."
public let EVENT_MEDIA_TITLE = "מדיה"
public let EVENT_MEDIA_EMPTY = "אין תמונות לאירוע זה."
public let EVENT_MEDIA_ADDED = "התמונה נוספה"
public let EVENT_MEDIA_UPDATED = "התמונה עודכנה"
public let EVENT_MEDIA_DELETED = "התמונה נמחקה"
public let EVENT_MEDIA_TAB_LABEL = "מדיה"
public let EVENT_MEDIA_DOCS_TAB_LABEL = "תיעוד"

public enum EventMediaTakenWhen: String, Equatable, Sendable, CaseIterable {
    case beforeTreatment = "before_treatment"
    case duringAfterTreatment = "during_after_treatment"
}

public func eventMediaTakenWhenLabel(_ value: EventMediaTakenWhen) -> String {
    switch value {
    case .beforeTreatment: return "לפני הטיפול"
    case .duringAfterTreatment: return "במהלך/לאחר הטיפול"
    }
}

public func parseEventMediaTakenWhen(_ raw: String) -> EventMediaTakenWhen? {
    EventMediaTakenWhen(rawValue: raw)
}

public struct EventMedia: Equatable, Sendable, Identifiable {
    public var id: String
    public var eventId: String
    public var uploadedBy: String
    public var uploaderName: String?
    public var treatedPlateIds: [String]
    public var caption: String?
    public var takenWhen: EventMediaTakenWhen
    public var storagePath: String
    public var mimeType: String
    public var byteSize: Int
    public var width: Int?
    public var height: Int?
    public var createdAt: String
    public var signedUrl: String?

    public init(
        id: String,
        eventId: String,
        uploadedBy: String,
        uploaderName: String?,
        treatedPlateIds: [String],
        caption: String?,
        takenWhen: EventMediaTakenWhen,
        storagePath: String,
        mimeType: String,
        byteSize: Int,
        width: Int?,
        height: Int?,
        createdAt: String,
        signedUrl: String?
    ) {
        self.id = id
        self.eventId = eventId
        self.uploadedBy = uploadedBy
        self.uploaderName = uploaderName
        self.treatedPlateIds = treatedPlateIds
        self.caption = caption
        self.takenWhen = takenWhen
        self.storagePath = storagePath
        self.mimeType = mimeType
        self.byteSize = byteSize
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.signedUrl = signedUrl
    }
}

public struct EventMediaPlateOption: Equatable, Sendable, Identifiable {
    public var id: String
    public var plateNumber: String
    public var model: String?
    public var color: String?
    public var logoSlug: String?

    public init(
        id: String,
        plateNumber: String,
        model: String?,
        color: String?,
        logoSlug: String?
    ) {
        self.id = id
        self.plateNumber = plateNumber
        self.model = model
        self.color = color
        self.logoSlug = logoSlug
    }
}

public struct EventMediaBands: Equatable, Sendable {
    public var before: [EventMedia]
    public var during: [EventMedia]

    public init(before: [EventMedia], during: [EventMedia]) {
        self.before = before
        self.during = during
    }
}

public func leftoverEventMediaError(unfinishedDraftCount: Int, mode: FillMode) -> String? {
    if mode != .complete { return nil }
    if unfinishedDraftCount <= 0 { return nil }
    return EVENT_MEDIA_LEFTOVER_ERROR
}

public func captionError(_ caption: String) -> String? {
    if caption.count <= EVENT_MEDIA_CAPTION_MAX { return nil }
    return EVENT_MEDIA_CAPTION_ERROR
}

public func slotsRemaining(savedCount: Int, inFlightCount: Int) -> Int {
    max(0, EVENT_MEDIA_CAP - savedCount - inFlightCount)
}

public func canAddMoreMedia(savedCount: Int, inFlightCount: Int) -> Bool {
    slotsRemaining(savedCount: savedCount, inFlightCount: inFlightCount) > 0
}

public func groupMediaByTakenWhen(_ items: [EventMedia]) -> EventMediaBands {
    EventMediaBands(
        before: items.filter { $0.takenWhen == .beforeTreatment }.sorted { $0.createdAt < $1.createdAt },
        during: items.filter { $0.takenWhen == .duringAfterTreatment }.sorted { $0.createdAt < $1.createdAt }
    )
}

public func eventMediaStoragePath(eventId: String, mediaId: String) -> String {
    "\(eventId)/\(mediaId).jpg"
}

public func mergeMediaPlates(
    responderKeyed: [EventMediaPlateOption],
    eventKeyed: [EventMediaPlateOption]
) -> [EventMediaPlateOption] {
    var seen = Set<String>()
    var out: [EventMediaPlateOption] = []
    for row in responderKeyed + eventKeyed {
        if seen.insert(row.id).inserted {
            out.append(row)
        }
    }
    return out
}

public func uniquePlateIds(_ ids: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for id in ids {
        if id.isEmpty { continue }
        if seen.insert(id).inserted {
            out.append(id)
        }
    }
    return out
}

public func togglePlateId(_ ids: [String], id: String) -> [String] {
    if id.isEmpty { return uniquePlateIds(ids) }
    if ids.contains(id) {
        return ids.filter { $0 != id }
    }
    return uniquePlateIds(ids + [id])
}

public func mapEventMediaError(_ message: String?) -> String {
    if message?.contains("event_media_cap") == true { return EVENT_MEDIA_CAP_ERROR }
    return EVENT_MEDIA_NETWORK
}

public func mediaPlateLabel(_ plate: EventMediaPlateOption) -> String {
    let caption = treatedPlateCaption(model: plate.model, color: plate.color)
    let plateLabel = formatPlate(plate.plateNumber)
    if let caption {
        return "\(plateLabel) \(caption)"
    }
    return plateLabel
}

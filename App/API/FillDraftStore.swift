import Foundation
import YahpazDomain

struct StashedResponderFill: Equatable, Sendable {
    var savedAt: Int64
    var draft: ResponderFillDraft
}

/// Device-local mirror of an in-progress fill draft.
/// Typed מלל lives in RAM until an explicit save; a photo picker, process death, or Back must not wipe it.
@MainActor
enum FillDraftStore {
    private static let suiteName = "yahpaz_fill_draft"
    private static var live: [String: ResponderFillDraft] = [:]
    private static let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }()
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    static func rememberLive(assignmentId: String, draft: ResponderFillDraft) {
        live[assignmentId] = draft
    }

    static func liveDraft(assignmentId: String) -> ResponderFillDraft? {
        live[assignmentId]
    }

    static func stash(assignmentId: String, draft: ResponderFillDraft, now: Int64) {
        rememberLive(assignmentId: assignmentId, draft: draft)
        let payload = StashedFillDraftPayload(savedAt: now, draft: StashedResponderFillDraft(draft))
        do {
            let data = try encoder.encode(payload)
            defaults.set(data, forKey: key(assignmentId))
        } catch {
            // A full quota must never break the form the user is typing into.
        }
    }

    static func read(assignmentId: String, now: Int64) -> StashedResponderFill? {
        guard let data = defaults.data(forKey: key(assignmentId)) else { return nil }
        let parsed: StashedFillDraftPayload
        do {
            parsed = try decoder.decode(StashedFillDraftPayload.self, from: data)
        } catch {
            clear(assignmentId: assignmentId)
            return nil
        }
        if !isFillDraftStashFresh(savedAt: parsed.savedAt, now: now) {
            clear(assignmentId: assignmentId)
            return nil
        }
        let draft = parsed.draft.toDomain()
        if live[assignmentId] == nil {
            rememberLive(assignmentId: assignmentId, draft: draft)
        }
        return StashedResponderFill(savedAt: parsed.savedAt, draft: draft)
    }

    static func clear(assignmentId: String) {
        live.removeValue(forKey: assignmentId)
        defaults.removeObject(forKey: key(assignmentId))
    }

    private static func key(_ assignmentId: String) -> String {
        fillDraftKey(scope: FILL_DRAFT_STASH_SCOPE, id: assignmentId)
    }
}

private struct StashedFillDraftPayload: Codable {
    var savedAt: Int64
    var draft: StashedResponderFillDraft
}

private struct StashedResponderFillDraft: Codable {
    var vehiclePlate: String
    var odometerStart: String
    var odometerEnd: String
    var route: String
    var treatmentDetail: String
    var treatmentNotes: String
    var treatedPlates: [StashedTreatedPlate]
    var treatedPlatePending: String

    init(_ draft: ResponderFillDraft) {
        vehiclePlate = draft.vehiclePlate
        odometerStart = draft.odometerStart
        odometerEnd = draft.odometerEnd
        route = draft.route
        treatmentDetail = draft.treatmentDetail
        treatmentNotes = draft.treatmentNotes
        treatedPlates = draft.treatedPlates.map(StashedTreatedPlate.init)
        treatedPlatePending = draft.treatedPlatePending
    }

    func toDomain() -> ResponderFillDraft {
        ResponderFillDraft(
            vehiclePlate: vehiclePlate,
            odometerStart: odometerStart,
            odometerEnd: odometerEnd,
            route: route,
            treatmentDetail: treatmentDetail,
            treatmentNotes: treatmentNotes,
            treatedPlates: treatedPlates.map(\.toDomain),
            treatedPlatePending: treatedPlatePending
        )
    }
}

private struct StashedTreatedPlate: Codable {
    var plateNumber: String
    var model: String?
    var color: String?
    var leftWhere: String?
    var manufacturer: String?
    var logoSlug: String?

    init(_ plate: TreatedPlate) {
        plateNumber = plate.plateNumber
        model = plate.model
        color = plate.color
        leftWhere = plate.leftWhere
        manufacturer = plate.manufacturer
        logoSlug = plate.logoSlug
    }

    var toDomain: TreatedPlate {
        TreatedPlate(
            plateNumber: plateNumber,
            model: model,
            color: color,
            leftWhere: leftWhere,
            manufacturer: manufacturer,
            logoSlug: logoSlug
        )
    }
}

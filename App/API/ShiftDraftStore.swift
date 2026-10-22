import Foundation
import YahpazDomain

/// Device copy of a new shift the lead has not saved yet. Same 24-hour window
/// as Android `ShiftDraftStore`.
@MainActor
enum ShiftDraftStore {
    private static let key = "yahpaz_shift_draft.new_shift_draft"
    private static let maxAgeMs: Int64 = 24 * 60 * 60 * 1000
    private static let defaults = UserDefaults.standard

    static func stash(_ draft: ShiftDraft, now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        let payload = StashedShiftPayload(
            savedAt: now,
            shiftDate: draft.shiftDate,
            shiftKind: draft.shiftKind,
            vehicleType: draft.vehicleType,
            notes: draft.notes,
            responderIds: draft.responderIds,
            personalVehicleId: draft.personalVehicleId
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    static func read(now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> ShiftDraft? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let parsed = try? JSONDecoder().decode(StashedShiftPayload.self, from: data) else {
            clear()
            return nil
        }
        if now - parsed.savedAt > maxAgeMs {
            clear()
            return nil
        }
        return ShiftDraft(
            shiftDate: parsed.shiftDate,
            shiftKind: parsed.shiftKind,
            vehicleType: parsed.vehicleType,
            notes: parsed.notes,
            responderIds: parsed.responderIds,
            personalVehicleId: parsed.personalVehicleId
        )
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }
}

/// Anything past the prefilled date is worth keeping on the device.
func shiftDraftHasDetail(_ draft: ShiftDraft) -> Bool {
    !draft.shiftKind.isEmpty || !draft.vehicleType.isEmpty
        || !draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !draft.responderIds.isEmpty
}

private struct StashedShiftPayload: Codable {
    var savedAt: Int64
    var shiftDate: String
    var shiftKind: String
    var vehicleType: String
    var notes: String
    var responderIds: [String]
    var personalVehicleId: String?
}

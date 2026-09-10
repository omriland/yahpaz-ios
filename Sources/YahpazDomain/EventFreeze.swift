import Foundation

public struct EventFreezeFlags: Equatable, Sendable {
    public var frozenOver60km: Bool
    public var frozenSuspiciousDuplicate: Bool

    public init(frozenOver60km: Bool = false, frozenSuspiciousDuplicate: Bool = false) {
        self.frozenOver60km = frozenOver60km
        self.frozenSuspiciousDuplicate = frozenSuspiciousDuplicate
    }

    public var isFrozen: Bool { frozenOver60km || frozenSuspiciousDuplicate }
    public var countsTowardFuelRefund: Bool { !isFrozen }

    public var tooltipHe: String? {
        if frozenOver60km && frozenSuspiciousDuplicate {
            return "האירוע מוקפא בגלל חריגת קילומטרים (מעל 60 ק״מ) ובגלל חשד לאירוע כפול, וממתין לאישור מנהל."
        }
        if frozenOver60km {
            return "האירוע מוקפא בגלל חריגת קילומטרים (מעל 60 ק״מ) וממתין לאישור מנהל."
        }
        if frozenSuspiciousDuplicate {
            return "האירוע מוקפא בגלל חשד לאירוע כפול וממתין לאישור מנהל."
        }
        return nil
    }
}

public func computeFreezeFlags(
    matchesOver60km: Bool,
    matchesSuspiciousDuplicate: Bool,
    approvedOver60km: Bool,
    approvedSuspiciousDuplicate: Bool
) -> EventFreezeFlags {
    EventFreezeFlags(
        frozenOver60km: matchesOver60km && !approvedOver60km,
        frozenSuspiciousDuplicate: matchesSuspiciousDuplicate && !approvedSuspiciousDuplicate
    )
}

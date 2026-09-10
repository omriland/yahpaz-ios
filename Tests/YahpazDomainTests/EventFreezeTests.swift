import XCTest
@testable import YahpazDomain

final class EventFreezeTests: XCTestCase {
    func testBothReasonsFreezeAndExcludeFromFuelRefund() {
        let flags = computeFreezeFlags(
            matchesOver60km: true,
            matchesSuspiciousDuplicate: true,
            approvedOver60km: false,
            approvedSuspiciousDuplicate: false
        )
        XCTAssertTrue(flags.isFrozen)
        XCTAssertFalse(flags.countsTowardFuelRefund)
        XCTAssertEqual(
            flags.tooltipHe,
            "האירוע מוקפא בגלל חריגת קילומטרים (מעל 60 ק״מ) ובגלל חשד לאירוע כפול, וממתין לאישור מנהל."
        )
    }

    func testApproving60kmLeavesADuplicateFreezeInPlace() {
        let flags = computeFreezeFlags(
            matchesOver60km: true,
            matchesSuspiciousDuplicate: true,
            approvedOver60km: true,
            approvedSuspiciousDuplicate: false
        )
        XCTAssertTrue(flags.isFrozen)
        XCTAssertFalse(flags.frozenOver60km)
        XCTAssertTrue(flags.frozenSuspiciousDuplicate)
        XCTAssertFalse(flags.countsTowardFuelRefund)
    }

    func testApprovingBothReasonsUnfreezesAndCountsForFuelRefund() {
        let flags = computeFreezeFlags(
            matchesOver60km: true,
            matchesSuspiciousDuplicate: true,
            approvedOver60km: true,
            approvedSuspiciousDuplicate: true
        )
        XCTAssertFalse(flags.isFrozen)
        XCTAssertTrue(flags.countsTowardFuelRefund)
        XCTAssertNil(flags.tooltipHe)
    }
}

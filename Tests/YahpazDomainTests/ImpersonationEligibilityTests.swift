import XCTest
@testable import YahpazDomain

final class ImpersonationEligibilityTests: XCTestCase {
    private let actor = "actor-1"

    func testAllowsActiveNonSuperAdminOtherUser() {
        XCTAssertTrue(
            canImpersonateTarget(
                actorUserId: actor,
                target: ImpersonationTarget(id: "user-2", active: true, roles: ["responder"])
            )
        )
    }

    func testRejectsSelfInactiveAndSuperAdmin() {
        XCTAssertFalse(
            canImpersonateTarget(
                actorUserId: actor,
                target: ImpersonationTarget(id: actor, active: true, roles: ["admin"])
            )
        )
        XCTAssertFalse(
            canImpersonateTarget(
                actorUserId: actor,
                target: ImpersonationTarget(id: "user-2", active: false, roles: ["responder"])
            )
        )
        XCTAssertFalse(
            canImpersonateTarget(
                actorUserId: actor,
                target: ImpersonationTarget(id: "user-2", active: true, roles: ["admin", "super_admin"])
            )
        )
        XCTAssertFalse(
            canImpersonateTarget(
                actorUserId: nil,
                target: ImpersonationTarget(id: "user-2", active: true, roles: ["responder"])
            )
        )
    }
}

import XCTest
@testable import YahpazDomain

final class FuelRefundTests: XCTestCase {
    private let profiles = [
        FuelRefundProfileInput(id: "r2", fullName: "יוסי לוי", callsign: "44"),
        FuelRefundProfileInput(id: "r1", fullName: "דנה כהן", callsign: "12"),
    ]

    func testParticipationsWithoutKmAreIgnoredInTheTotalAndTheCount() {
        let rows = buildFuelRefundRows(
            profiles: profiles,
            participations: [
                FuelRefundParticipationInput(responderId: "r1", eventId: "e1", totalKm: 10.0),
                FuelRefundParticipationInput(responderId: "r1", eventId: "e2", totalKm: nil),
                FuelRefundParticipationInput(responderId: "r1", eventId: "e3", totalKm: 5.0),
            ]
        )
        let dana = rows.first { $0.id == "r1" }!
        XCTAssertEqual(dana.totalKm, 15.0)
        XCTAssertEqual(dana.eventCount, 2)
    }

    func testPrivateVehicleShiftCreditsAddKmWithoutAddingEvents() {
        let rows = buildFuelRefundRows(
            profiles: profiles,
            participations: [FuelRefundParticipationInput(responderId: "r1", eventId: "e1", totalKm: 10.0)],
            credits: [
                FuelRefundCreditInput(responderId: "r1", totalKm: 30.0),
                FuelRefundCreditInput(responderId: "r1", totalKm: 2.0),
            ]
        )
        let dana = rows.first { $0.id == "r1" }!
        XCTAssertEqual(dana.totalKm, 42.0)
        XCTAssertEqual(dana.eventCount, 1)
    }

    func testEveryActiveProfileAppearsEvenWithNoKm() {
        let rows = buildFuelRefundRows(profiles: profiles, participations: [])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].totalKm, 0.0)
    }

    func testRowsSortByFullName() {
        let rows = buildFuelRefundRows(profiles: profiles, participations: [])
        XCTAssertEqual(rows.map(\.fullName), ["דנה כהן", "יוסי לוי"])
    }

    func testReportRowsLabelTheEventCountInHebrew() {
        let rows = fuelRefundReportRows(
            buildFuelRefundRows(
                profiles: [FuelRefundProfileInput(id: "r1", fullName: "דנה כהן", callsign: "12")],
                participations: [FuelRefundParticipationInput(responderId: "r1", eventId: "e1", totalKm: 1200.5)]
            )
        )
        XCTAssertEqual(rows[0].title, "דנה כהן · 12")
        XCTAssertEqual(rows[0].subtitle, "אירוע אחד")
        XCTAssertEqual(rows[0].trailing, "1,200.5 ק״מ")
    }
}

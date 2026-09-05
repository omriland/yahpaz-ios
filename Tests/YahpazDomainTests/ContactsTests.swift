import XCTest
@testable import YahpazDomain

final class ContactsTests: XCTestCase {
    private let dana = ContactSearchFields(
        fullName: "דנה כהן",
        callsign: "12",
        email: "dana@yahpz.com",
        phone: "050-123-4567"
    )
    private let ofer = ContactSearchFields(
        fullName: "אופר לוי",
        callsign: "7",
        email: "ofer@yahpz.com",
        phone: nil
    )

    func testPhoneFormattingAndHrefsMatchTheWeb() {
        XCTAssertEqual(formatPhone("050-123-4567"), "050-1234567")
        XCTAssertEqual(telHref("0501234567"), "tel:+972501234567")
        XCTAssertEqual(whatsAppHref("050-1234567"), "https://wa.me/972501234567")
        XCTAssertNil(telHref("05012345"))
        XCTAssertNil(whatsAppHref("021234567"))
        XCTAssertTrue(isValidIlMobile("0521234567"))
        XCTAssertFalse(isValidIlMobile("0212345678"))
    }

    func testFilterMatchesNameCallsignEmailAndDigits() {
        let all = [dana, ofer]
        XCTAssertEqual(filterContacts(all, query: "  ") { $0 }, all)
        XCTAssertEqual(filterContacts(all, query: "דנה") { $0 }, [dana])
        XCTAssertEqual(filterContacts(all, query: "ofer@") { $0 }, [ofer])
        XCTAssertTrue(filterContacts(all, query: "אין כזה") { $0 }.isEmpty)
    }

    func testDigitSearchIgnoresPhoneFormatting() {
        XCTAssertTrue(contactMatchesQuery(dana, query: "0501234567"))
        XCTAssertTrue(contactMatchesQuery(dana, query: "12-34"))
        XCTAssertFalse(contactMatchesQuery(dana, query: "9-8"))
    }
}

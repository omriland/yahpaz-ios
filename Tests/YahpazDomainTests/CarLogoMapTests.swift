import XCTest
@testable import YahpazDomain

final class CarLogoMapTests: XCTestCase {
    func testVolkswagenStripsGermanSuffix() {
        XCTAssertEqual(resolveCarLogoSlug("פולקסווגן גרמנ"), "volkswagen")
    }

    func testSsangyongStripsKoreaAbbrev() {
        XCTAssertEqual(resolveCarLogoSlug("סאנגיונג ד.קור"), "ssangyong")
    }

    func testCommonHebrewBrands() {
        XCTAssertEqual(resolveCarLogoSlug("טויוטה יפן"), "toyota")
        XCTAssertEqual(resolveCarLogoSlug("יונדאי קוריאה"), "hyundai")
        XCTAssertEqual(resolveCarLogoSlug("קיה"), "kia")
        XCTAssertEqual(resolveCarLogoSlug("סקודה"), "skoda")
        XCTAssertEqual(resolveCarLogoSlug("ב מ וו"), "bmw")
    }

    func testLatinAndMixed() {
        XCTAssertEqual(resolveCarLogoSlug("BYD China"), "byd")
        XCTAssertEqual(resolveCarLogoSlug("TESLA"), "tesla")
    }

    func testUnknownOrBlankIsNil() {
        XCTAssertNil(resolveCarLogoSlug(""))
        XCTAssertNil(resolveCarLogoSlug("   "))
        XCTAssertNil(resolveCarLogoSlug("יצרן לא קיים בעולם"))
    }
}

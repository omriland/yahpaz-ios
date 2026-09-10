import XCTest
@testable import YahpazDomain

final class CompressEventImageTests: XCTestCase {
    func testRejectEmptyVideoAndOversized() {
        XCTAssertEqual(rejectOriginalFile(mimeType: "image/jpeg", byteSize: 0), EVENT_MEDIA_BAD_TYPE)
        XCTAssertEqual(rejectOriginalFile(mimeType: "video/mp4", byteSize: 1000), EVENT_MEDIA_BAD_TYPE)
        XCTAssertEqual(rejectOriginalFile(mimeType: "application/pdf", byteSize: 1000), EVENT_MEDIA_BAD_TYPE)
        XCTAssertEqual(
            rejectOriginalFile(mimeType: "image/jpeg", byteSize: EVENT_MEDIA_MAX_ORIGINAL_BYTES + 1),
            EVENT_MEDIA_TOO_LARGE
        )
    }

    func testAllowCommonImageTypesUnderCap() {
        XCTAssertNil(rejectOriginalFile(mimeType: "image/jpeg", byteSize: 1000))
        XCTAssertNil(rejectOriginalFile(mimeType: "image/png", byteSize: 1000))
        XCTAssertNil(rejectOriginalFile(mimeType: "image/webp", byteSize: 1000))
        XCTAssertNil(rejectOriginalFile(mimeType: "image/heic", byteSize: 1000))
        XCTAssertNil(rejectOriginalFile(mimeType: "image/heif", byteSize: 1000))
    }

    func testNeverUpscale() {
        let size = targetDimensions(width: 800, height: 600)
        XCTAssertEqual(size.0, 800)
        XCTAssertEqual(size.1, 600)
    }

    func testFitLongEdgeTo1600() {
        let landscape = targetDimensions(width: 3200, height: 2400)
        XCTAssertEqual(landscape.0, 1600)
        XCTAssertEqual(landscape.1, 1200)
        let portrait = targetDimensions(width: 1200, height: 3200)
        XCTAssertEqual(portrait.0, 600)
        XCTAssertEqual(portrait.1, 1600)
        XCTAssertEqual(EVENT_MEDIA_MAX_LONG_EDGE, 1600)
    }

    func testNextJpegQualityStopsWhenSmallEnough() {
        XCTAssertNil(nextJpegQuality(byteSize: 500_000, qualityIndex: 0))
    }

    func testNextJpegQualityStepsThenNull() {
        XCTAssertEqual(nextJpegQuality(byteSize: 800_000, qualityIndex: 0), 0.6)
        XCTAssertEqual(nextJpegQuality(byteSize: 800_000, qualityIndex: 1), 0.5)
        XCTAssertNil(nextJpegQuality(byteSize: 800_000, qualityIndex: 2))
    }

    func testJpegQualityPercentMatchesAndroidCompressScale() {
        XCTAssertEqual(jpegQualityPercent(0.72), 72)
        XCTAssertEqual(jpegQualityPercent(0.6), 60)
        XCTAssertEqual(jpegQualityPercent(0.5), 50)
    }
}

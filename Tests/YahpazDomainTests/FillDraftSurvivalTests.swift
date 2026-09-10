import XCTest
@testable import YahpazDomain

final class FillDraftSurvivalTests: XCTestCase {
    private let now: Int64 = 1_788_000_000_000
    private let server = ResponderFillDraft(treatmentDetail: "מהשרת")
    private let typed = ResponderFillDraft(treatmentDetail: "חילוץ מכביש 6")

    func testStashKeysAreScopedPerFlow() {
        XCTAssertEqual(fillDraftKey(scope: "responder", id: "a1"), "yahpaz.fillDraft.responder.a1")
        XCTAssertNotEqual(
            fillDraftKey(scope: "responder", id: "a1"),
            fillDraftKey(scope: "shiftBorn", id: "a1")
        )
    }

    func testKeepLiveBootOnlyWhenReadyWithTypedDraft() {
        XCTAssertTrue(shouldKeepLiveFormBoot(loadState: "ready", hasTypedDraft: true))
        XCTAssertFalse(shouldKeepLiveFormBoot(loadState: "loading", hasTypedDraft: true))
        XCTAssertFalse(shouldKeepLiveFormBoot(loadState: "denied", hasTypedDraft: true))
        XCTAssertFalse(shouldKeepLiveFormBoot(loadState: "ready", hasTypedDraft: false))
    }

    func testPreferStashWhenItDiffersAndIsFresh() {
        XCTAssertTrue(
            shouldPreferStashedFillDraft(
                stashed: typed,
                savedAt: now,
                server: server,
                now: now
            )
        )
        XCTAssertFalse(
            shouldPreferStashedFillDraft(
                stashed: server,
                savedAt: now,
                server: server,
                now: now
            )
        )
    }

    func testIgnoreMissingOrStaleStash() {
        XCTAssertFalse(
            shouldPreferStashedFillDraft(
                stashed: nil,
                savedAt: now,
                server: server,
                now: now
            )
        )
        XCTAssertFalse(
            shouldPreferStashedFillDraft(
                stashed: typed,
                savedAt: now - FILL_DRAFT_MAX_AGE_MS - 1,
                server: server,
                now: now
            )
        )
        XCTAssertTrue(
            shouldPreferStashedFillDraft(
                stashed: typed,
                savedAt: now - FILL_DRAFT_MAX_AGE_MS + 1,
                server: server,
                now: now
            )
        )
    }

    func testBackDropsUnfinishedPhotoBeforeLeaving() {
        XCTAssertEqual(
            decideFillBack(onMediaPane: true, unfinishedMediaDraftCount: 1),
            .dropUnfinishedPhoto
        )
        XCTAssertEqual(
            decideFillBack(onMediaPane: false, unfinishedMediaDraftCount: 2),
            .dropUnfinishedPhoto
        )
    }

    func testBackFromMediaWithoutUnfinishedPhotoReturnsToDocs() {
        XCTAssertEqual(
            decideFillBack(onMediaPane: true, unfinishedMediaDraftCount: 0),
            .showDocs
        )
    }

    func testBackFromDocsLeavesAfterPersist() {
        XCTAssertEqual(
            decideFillBack(onMediaPane: false, unfinishedMediaDraftCount: 0),
            .leave
        )
    }

    func testSavedLabelIs24HourClock() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let noonJerusalem = formatter.date(from: "2026-05-01T09:00:00Z")!.timeIntervalSince1970 * 1000
        XCTAssertEqual(fillDraftSavedLabel(savedAtMillis: Int64(noonJerusalem)), "12:00")
    }
}

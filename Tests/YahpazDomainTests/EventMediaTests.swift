import XCTest
@testable import YahpazDomain

final class EventMediaTests: XCTestCase {
    private func media(patch: (EventMedia) -> EventMedia = { $0 }) -> EventMedia {
        let base = EventMedia(
            id: "m1",
            eventId: "e1",
            uploadedBy: "u1",
            uploaderName: "דנה",
            treatedPlateIds: [],
            caption: nil,
            takenWhen: .beforeTreatment,
            storagePath: "e1/m1.jpg",
            mimeType: "image/jpeg",
            byteSize: 1000,
            width: 800,
            height: 600,
            createdAt: "2026-08-19T10:00:00.000Z",
            signedUrl: nil
        )
        return patch(base)
    }

    func testLeftoverIgnoresDraftsOnDraftSave() {
        XCTAssertNil(leftoverEventMediaError(unfinishedDraftCount: 2, mode: .draft))
    }

    func testLeftoverBlocksCompleteWhenDraftMissingWhenTaken() {
        XCTAssertEqual(leftoverEventMediaError(unfinishedDraftCount: 1, mode: .complete), EVENT_MEDIA_LEFTOVER_ERROR)
    }

    func testLeftoverAllowsCompleteWithZeroUnfinished() {
        XCTAssertNil(leftoverEventMediaError(unfinishedDraftCount: 0, mode: .complete))
    }

    func testCaptionAllowsEmptyAnd200() {
        XCTAssertNil(captionError(""))
        XCTAssertNil(captionError(String(repeating: "א", count: 200)))
    }

    func testCaptionRejects201() {
        XCTAssertEqual(captionError(String(repeating: "א", count: 201)), EVENT_MEDIA_CAPTION_ERROR)
    }

    func testCapAllowsTwentiethAndBlocksTwentyFirst() {
        XCTAssertTrue(canAddMoreMedia(savedCount: 19, inFlightCount: 0))
        XCTAssertFalse(canAddMoreMedia(savedCount: 19, inFlightCount: 1))
        XCTAssertFalse(canAddMoreMedia(savedCount: 20, inFlightCount: 0))
        XCTAssertEqual(slotsRemaining(savedCount: 18, inFlightCount: 1), 1)
        XCTAssertEqual(EVENT_MEDIA_CAP, 20)
    }

    func testGroupSortsEachBandByCreatedAt() {
        let grouped = groupMediaByTakenWhen([
            media { $0.with(id: "b2", createdAt: "2026-08-19T12:00:00.000Z") },
            media {
                $0.with(
                    id: "d1",
                    takenWhen: .duringAfterTreatment,
                    createdAt: "2026-08-19T11:00:00.000Z"
                )
            },
            media { $0.with(id: "b1", createdAt: "2026-08-19T10:00:00.000Z") },
        ])
        XCTAssertEqual(grouped.before.map(\.id), ["b1", "b2"])
        XCTAssertEqual(grouped.during.map(\.id), ["d1"])
    }

    func testStoragePathIsEventIdSlashMediaIdJpg() {
        XCTAssertEqual(eventMediaStoragePath(eventId: "e1", mediaId: "m1"), "e1/m1.jpg")
    }

    func testMapEventMediaErrorMapsCap() {
        XCTAssertEqual(mapEventMediaError("event_media_cap"), EVENT_MEDIA_CAP_ERROR)
        XCTAssertEqual(mapEventMediaError("new row violates event_media_cap"), EVENT_MEDIA_CAP_ERROR)
        XCTAssertEqual(mapEventMediaError("jwt expired"), EVENT_MEDIA_NETWORK)
        XCTAssertEqual(mapEventMediaError(nil), EVENT_MEDIA_NETWORK)
    }

    func testTogglePlateIdAddsAndRemoves() {
        XCTAssertEqual(togglePlateId(["a"], id: "b"), ["a", "b"])
        XCTAssertEqual(togglePlateId(["a", "b"], id: "a"), ["b"])
    }

    func testUniquePlateIdsDropsBlanksAndDuplicates() {
        XCTAssertEqual(uniquePlateIds(["b", "", "a", "b"]), ["b", "a"])
    }

    func testMergeMediaPlatesUnionsById() {
        let a = EventMediaPlateOption(
            id: "a",
            plateNumber: "12-345-67",
            model: "REXTON",
            color: "שחור",
            logoSlug: "ssangyong"
        )
        let b = EventMediaPlateOption(
            id: "b",
            plateNumber: "123-45-678",
            model: nil,
            color: nil,
            logoSlug: nil
        )
        XCTAssertEqual(mergeMediaPlates(responderKeyed: [a], eventKeyed: [a, b]), [a, b])
    }
}

private extension EventMedia {
    func with(
        id: String? = nil,
        takenWhen: EventMediaTakenWhen? = nil,
        createdAt: String? = nil
    ) -> EventMedia {
        EventMedia(
            id: id ?? self.id,
            eventId: eventId,
            uploadedBy: uploadedBy,
            uploaderName: uploaderName,
            treatedPlateIds: treatedPlateIds,
            caption: caption,
            takenWhen: takenWhen ?? self.takenWhen,
            storagePath: storagePath,
            mimeType: mimeType,
            byteSize: byteSize,
            width: width,
            height: height,
            createdAt: createdAt ?? self.createdAt,
            signedUrl: signedUrl
        )
    }
}

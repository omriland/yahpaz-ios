import XCTest
@testable import YahpazDomain

final class UserFeedbackTests: XCTestCase {
    func testRequiresKindAndContent() {
        XCTAssertEqual(FEEDBACK_KIND_ERROR, feedbackSubmitError(kind: nil, body: "יש באג", hasAudio: false))
        XCTAssertEqual(FEEDBACK_EMPTY_ERROR, feedbackSubmitError(kind: "bug", body: "   ", hasAudio: false))
        XCTAssertNil(feedbackSubmitError(kind: "bug", body: "מסך קפוא", hasAudio: false))
        XCTAssertNil(feedbackSubmitError(kind: "suggestion", body: "", hasAudio: true))
    }

    func testRejectsLongBody() {
        XCTAssertNil(feedbackBodyError(String(repeating: "א", count: FEEDBACK_BODY_MAX)))
        XCTAssertEqual(
            FEEDBACK_BODY_ERROR,
            feedbackBodyError(String(repeating: "א", count: FEEDBACK_BODY_MAX + 1))
        )
    }

    func testMapsAudioMimeAndPath() {
        XCTAssertEqual("m4a", feedbackStorageExt("audio/mp4"))
        XCTAssertEqual("audio/mp4", normalizeFeedbackAudioMime("audio/mp4"))
        XCTAssertEqual("u1/f1.m4a", feedbackStoragePath(userId: "u1", feedbackId: "f1", mime: "audio/mp4"))
    }

    func testFormatsTimerAndCapsAtNinety() {
        XCTAssertEqual("00:00", formatRecordSeconds(0))
        XCTAssertEqual("00:09", formatRecordSeconds(9))
        XCTAssertEqual("01:15", formatRecordSeconds(75))
        XCTAssertEqual("01:30", formatRecordSeconds(200))
        XCTAssertTrue(shouldAutoStopRecording(90))
    }

    func testMapsAttachmentMimeAndPath() {
        XCTAssertEqual("image/jpeg", normalizeFeedbackAttachmentMime(mime: "image/jpeg", name: "a.jpg"))
        XCTAssertEqual("image/png", normalizeFeedbackAttachmentMime(mime: "", name: "screen.PNG"))
        XCTAssertEqual("image", feedbackAttachmentKind(mime: "image/webp", name: "x.webp"))
        XCTAssertEqual("video", feedbackAttachmentKind(mime: "video/mp4", name: "x.mp4"))
        XCTAssertEqual(
            "u1/f1/a1.png",
            feedbackAttachmentStoragePath(
                userId: "u1",
                feedbackId: "f1",
                attachmentId: "a1",
                mime: "image/png",
                name: "shot.png"
            )
        )
    }

    func testRejectsFourthAttachmentAndKeepsThree() {
        let current = [
            FeedbackPickedMeta(name: "1.jpg", mime: "image/jpeg", size: 10),
            FeedbackPickedMeta(name: "2.jpg", mime: "image/jpeg", size: 10),
            FeedbackPickedMeta(name: "3.jpg", mime: "image/jpeg", size: 10),
        ]
        let result = addFeedbackAttachments(
            current: current,
            incoming: [FeedbackPickedMeta(name: "4.jpg", mime: "image/jpeg", size: 10)]
        )
        XCTAssertEqual(FEEDBACK_ATTACH_MAX, result.files.count)
        XCTAssertEqual(FEEDBACK_ATTACH_COUNT_ERROR, result.error)
    }

    func testRejectsWrongTypeAndOversizedAttachments() {
        let pdf = addFeedbackAttachments(
            current: [],
            incoming: [FeedbackPickedMeta(name: "note.pdf", mime: "application/pdf", size: 10)]
        )
        XCTAssertTrue(pdf.files.isEmpty)
        XCTAssertEqual(FEEDBACK_ATTACH_TYPE_ERROR, pdf.error)

        let hugeImage = addFeedbackAttachments(
            current: [],
            incoming: [FeedbackPickedMeta(name: "big.jpg", mime: "image/jpeg", size: FEEDBACK_IMAGE_MAX_BYTES + 1)]
        )
        XCTAssertTrue(hugeImage.files.isEmpty)
        XCTAssertEqual(FEEDBACK_ATTACH_IMAGE_SIZE_ERROR, hugeImage.error)

        let hugeVideo = addFeedbackAttachments(
            current: [],
            incoming: [FeedbackPickedMeta(name: "big.mp4", mime: "video/mp4", size: FEEDBACK_VIDEO_MAX_BYTES + 1)]
        )
        XCTAssertTrue(hugeVideo.files.isEmpty)
        XCTAssertEqual(FEEDBACK_ATTACH_VIDEO_SIZE_ERROR, hugeVideo.error)
    }

    func testAcceptsValidImageAndVideo() {
        let image = addFeedbackAttachments(
            current: [],
            incoming: [FeedbackPickedMeta(name: "screen.jpg", mime: "image/jpeg", size: 1024)]
        )
        XCTAssertNil(image.error)
        XCTAssertEqual(1, image.files.count)
        let video = addFeedbackAttachments(
            current: image.files,
            incoming: [FeedbackPickedMeta(name: "clip.mp4", mime: "video/mp4", size: 2048)]
        )
        XCTAssertNil(video.error)
        XCTAssertEqual(2, video.files.count)
    }

    func testSanitizesAttachmentName() {
        XCTAssertEqual("..evilname.png", sanitizeFeedbackAttachmentName("  ../evil\\name.png  "))
    }

    func testBuildsPagePath() {
        XCTAssertEqual("/fill/e1", feedbackPagePath(fillEventId: "e1", tab: "INBOX", toolsDestination: "HUB"))
        XCTAssertEqual("/new_event", feedbackPagePath(fillEventId: nil, tab: "INBOX", toolsDestination: "NEW_EVENT"))
        XCTAssertEqual("/inbox", feedbackPagePath(fillEventId: nil, tab: "INBOX", toolsDestination: "HUB"))
    }

    func testHidesFabOnFillAndEventShiftForms() {
        XCTAssertTrue(shouldShowFeedbackFab(hiddenUntilRefresh: false, overlay: "HUB", fillOpen: false))
        XCTAssertFalse(shouldShowFeedbackFab(hiddenUntilRefresh: true, overlay: "HUB", fillOpen: false))
        XCTAssertFalse(shouldShowFeedbackFab(hiddenUntilRefresh: false, overlay: "HUB", fillOpen: true))
        XCTAssertFalse(shouldShowFeedbackFab(hiddenUntilRefresh: false, overlay: "NEW_EVENT", fillOpen: false))
        XCTAssertFalse(shouldShowFeedbackFab(hiddenUntilRefresh: false, overlay: "EDIT_EVENT", fillOpen: false))
        XCTAssertFalse(shouldShowFeedbackFab(hiddenUntilRefresh: false, overlay: "NEW_SHIFT", fillOpen: false))
        XCTAssertFalse(shouldShowFeedbackFab(hiddenUntilRefresh: false, overlay: "EDIT_SHIFT", fillOpen: false))
    }
}

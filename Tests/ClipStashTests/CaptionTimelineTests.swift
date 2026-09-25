import XCTest
@testable import ClipStash

final class CaptionTimelineTests: XCTestCase {
    func testFinalQueuedWhilePartialInFlightKeepsIdentityAndFinalFlag() throws {
        var timeline = CaptionTimeline()
        timeline.ingest("Hello", isFinal: false)
        let partial = try XCTUnwrap(timeline.next())
        timeline.ingest("Hello world.", isFinal: true)
        let final = try XCTUnwrap(timeline.next())
        XCTAssertEqual(partial.rowID, final.rowID)
        XCTAssertTrue(final.isFinal)
        XCTAssertEqual(timeline.rows.count, 1)
    }

    func testRevisionDoesNotShrinkTranslationOrMismatchSource() throws {
        var timeline = CaptionTimeline()
        timeline.ingest("Hello", isFinal: false)
        let first = try XCTUnwrap(timeline.next())
        timeline.show("你好", for: first, complete: true)
        timeline.ingest("Hello world.", isFinal: true)
        let next = try XCTUnwrap(timeline.next())
        timeline.show("你", for: next)
        XCTAssertEqual(timeline.rows[0].translation, "你好")
        XCTAssertEqual(timeline.rows[0].displayedSource, "Hello")
        timeline.show("你好，世界。", for: next, complete: true)
        XCTAssertEqual(timeline.rows[0].displayedSource, "Hello world.")
        XCTAssertEqual(timeline.rows.count, 1)
    }

    func testOldStreamCannotWriteIntoNextParagraph() throws {
        var timeline = CaptionTimeline()
        timeline.ingest("First.", isFinal: true)
        let first = try XCTUnwrap(timeline.next())
        timeline.ingest("Second.", isFinal: true)
        timeline.show("第一。", for: first, complete: true)
        XCTAssertEqual(timeline.rows[0].translation, "第一。")
        XCTAssertEqual(timeline.rows[1].translation, "")
        XCTAssertNotEqual(timeline.rows[0].id, timeline.rows[1].id)
    }
}

import AppKit
import XCTest
@testable import ClipStash

final class ScreenCaptureServiceTests: XCTestCase {
    func testDeniedPermissionProducesActionableFailure() {
        assertFailure(.permissionRequired, imageData: nil, status: 1,
                      diagnostics: "could not create image from rect", hasPermission: false)
    }

    func testEscapeIsCancellationForBothExitStatuses() {
        for status: Int32 in [0, 1] {
            let result = outcome(imageData: nil, status: status, diagnostics: "\n")
            guard case .cancelled = result else {
                return XCTFail("Escape with status \(status) should be cancellation")
            }
        }
    }

    func testCaptureErrorIsNotSilentlyTreatedAsCancellation() {
        assertFailure(.commandFailed(1), imageData: nil, status: 1,
                      diagnostics: "screencapture: capture error could not create image from rect")
    }

    func testUnexpectedExitStatusAndSignalAreFailures() {
        assertFailure(.commandFailed(2), imageData: nil, status: 2)
        let result = ScreenCaptureService.outcome(imageData: nil, status: 9, diagnostics: "",
                                                 exitedNormally: false, hasPermission: true)
        guard case .failed(.commandFailed(9)) = result else {
            return XCTFail("A terminated screenshot process must not be mistaken for Escape")
        }
    }

    func testMalformedImageDoesNotOpenAnEmptyEditor() {
        assertFailure(.invalidImage, imageData: Data("not a PNG".utf8), status: 0)
        assertFailure(.invalidImage, imageData: Data(), status: 0)
    }

    func testSuccessfulCapturePreservesImageDimensions() throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 24,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                                  bytesPerRow: 0, bitsPerPixel: 0))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let result = outcome(imageData: png, status: 0, diagnostics: "")
        guard case .captured(let screenshot) = result else {
            return XCTFail("A valid PNG must reach the editor")
        }
        XCTAssertEqual(screenshot.image.size.width, 40)
        XCTAssertEqual(screenshot.image.size.height, 24)
        XCTAssertNil(screenshot.screenRect)
    }

    func testCaptureMetadataDecodesGlobalRectangle() throws {
        let metadata = try PropertyListSerialization.data(
            fromPropertyList: [287.0, 72.0, 822.0, 731.0],
            format: .binary,
            options: 0
        )
        let rect = try XCTUnwrap(ScreenCaptureService.captureRect(fromMetadata: metadata))
        XCTAssertEqual(rect, NSRect(x: 287, y: 72, width: 822, height: 731))
    }

    func testInvalidCaptureMetadataIsIgnored() {
        XCTAssertNil(ScreenCaptureService.captureRect(fromMetadata: Data("invalid".utf8)))
    }

    func testEditorFrameMatchesNormalCaptureBounds() {
        let visibleFrame = NSRect(x: 0, y: 62, width: 1512, height: 887)
        let captureRect = NSRect(x: 287, y: 179, width: 822, height: 731)
        let frame = ScreenshotEditorWindow.editorFrame(
            imageSize: NSSize(width: 1644, height: 1462),
            captureRect: captureRect,
            visibleFrame: visibleFrame
        )
        XCTAssertEqual(frame, captureRect)
    }

    func testEditorFrameExpandsTinyCaptureAroundItsCenter() {
        let captureRect = NSRect(x: 500, y: 400, width: 120, height: 80)
        let frame = ScreenshotEditorWindow.editorFrame(
            imageSize: NSSize(width: 240, height: 160),
            captureRect: captureRect,
            visibleFrame: NSRect(x: 0, y: 0, width: 1512, height: 982)
        )
        XCTAssertEqual(frame.size, NSSize(width: 360, height: 300))
        XCTAssertEqual(frame.midX, captureRect.midX)
        XCTAssertEqual(frame.midY, captureRect.midY)
    }

    func testEditorFrameConstrainsOversizedCaptureToVisibleScreen() {
        let visibleFrame = NSRect(x: 0, y: 62, width: 1512, height: 887)
        let frame = ScreenshotEditorWindow.editorFrame(
            imageSize: NSSize(width: 3024, height: 1964),
            captureRect: NSRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: visibleFrame
        )
        XCTAssertEqual(frame, NSRect(x: 12, y: 74, width: 1488, height: 863))
    }

    func testFailedProcessCannotReturnPartialImageAsSuccess() {
        assertFailure(.commandFailed(1), imageData: Data("partial file".utf8), status: 1)
    }

    private func outcome(imageData: Data?, status: Int32, diagnostics: String) -> ScreenCaptureOutcome {
        ScreenCaptureService.outcome(imageData: imageData, status: status, diagnostics: diagnostics,
                                     exitedNormally: true, hasPermission: true)
    }

    private func assertFailure(_ expected: ScreenCaptureFailure, imageData: Data?, status: Int32,
                               diagnostics: String = "", hasPermission: Bool = true,
                               file: StaticString = #filePath, line: UInt = #line) {
        let result = ScreenCaptureService.outcome(imageData: imageData, status: status, diagnostics: diagnostics,
                                                 exitedNormally: true, hasPermission: hasPermission)
        guard case .failed(let actual) = result else {
            return XCTFail("Expected \(expected)", file: file, line: line)
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }
}

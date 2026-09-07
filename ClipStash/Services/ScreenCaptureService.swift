import AppKit
import CoreGraphics
import Darwin
import Foundation
import OSLog

struct CapturedScreenshot {
    let image: NSImage
    let screenRect: NSRect?
}

enum ScreenCaptureOutcome {
    case captured(CapturedScreenshot)
    case cancelled
    case failed(ScreenCaptureFailure)
}

enum ScreenCaptureFailure: Error, Equatable {
    case permissionRequired
    case couldNotStart
    case commandFailed(Int32)
    case invalidImage
}

/// Uses the macOS interactive screenshot selector. All callbacks run on the main thread.
final class ScreenCaptureService {
    var onCompletion: ((ScreenCaptureOutcome) -> Void)?
    private(set) var isCapturing = false
    private static let logger = Logger(subsystem: "com.clipstash.app", category: "ScreenCapture")

    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func openPermissionSettings() {
        if !hasPermission {
            CGRequestScreenCaptureAccess()
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func startCapture() {
        guard !isCapturing else { return }
        guard Self.hasPermission else {
            onCompletion?(.failed(.permissionRequired))
            return
        }
        isCapturing = true

        // Let the panel disappear and the initiating shortcut's modifiers be released.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.waitForModifiersAndCapture()
        }
    }

    private func waitForModifiersAndCapture() {
        let modifiers = NSEvent.modifierFlags.intersection([.command, .control, .option, .shift])
        guard modifiers.isEmpty else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.waitForModifiersAndCapture()
            }
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipstash-\(UUID().uuidString).png")

        // Drain stderr before waiting so a full pipe cannot block the child process.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer { try? FileManager.default.removeItem(at: tempURL) }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-i", "-x", "-r", "-t", "png", tempURL.path]
            let errorPipe = Pipe()
            task.standardError = errorPipe
            task.standardOutput = FileHandle.nullDevice

            do {
                try task.run()
            } catch {
                Self.logger.error("Could not launch screencapture: \(error.localizedDescription)")
                DispatchQueue.main.async { self?.finish(.failed(.couldNotStart)) }
                return
            }

            let diagnostics = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            task.waitUntilExit()
            let imageData = try? Data(contentsOf: tempURL)
            let captureRect = imageData == nil ? nil : Self.screenCaptureRect(at: tempURL)
            let status = task.terminationStatus
            let exitedNormally = task.terminationReason == .exit
            Self.logger.info("screencapture exited with status \(status), image created: \(imageData != nil)")
            if !diagnostics.isEmpty {
                Self.logger.error("screencapture stderr: \(diagnostics)")
            }

            DispatchQueue.main.async {
                self?.finish(Self.outcome(
                    imageData: imageData,
                    status: status,
                    diagnostics: diagnostics,
                    exitedNormally: exitedNormally,
                    hasPermission: Self.hasPermission,
                    captureRect: captureRect
                ))
            }
        }
    }

    private func finish(_ outcome: ScreenCaptureOutcome) {
        isCapturing = false
        onCompletion?(outcome)
    }

    static func outcome(
        imageData: Data?,
        status: Int32,
        diagnostics: String,
        exitedNormally: Bool,
        hasPermission: Bool,
        captureRect: NSRect? = nil
    ) -> ScreenCaptureOutcome {
        guard hasPermission else { return .failed(.permissionRequired) }
        guard exitedNormally else { return .failed(.commandFailed(status)) }
        if let imageData {
            guard status == 0 else { return .failed(.commandFailed(status)) }
            guard let image = NSImage(data: imageData), image.size.width > 0, image.size.height > 0 else {
                return .failed(.invalidImage)
            }
            return .captured(CapturedScreenshot(image: image, screenRect: captureRect))
        }
        // Escape produces no file and may exit with either 0 or 1, without diagnostics.
        if (status == 0 || status == 1) && diagnostics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .cancelled
        }
        return .failed(.commandFailed(status))
    }

    static func captureRect(fromMetadata data: Data) -> NSRect? {
        guard let propertyList = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let values = propertyList as? [NSNumber],
              values.count == 4 else { return nil }

        let rect = NSRect(
            x: values[0].doubleValue,
            y: values[1].doubleValue,
            width: values[2].doubleValue,
            height: values[3].doubleValue
        )
        guard rect.width > 0, rect.height > 0 else { return nil }
        return rect
    }

    private static func screenCaptureRect(at url: URL) -> NSRect? {
        let attributeName = "com.apple.metadata:kMDItemScreenCaptureGlobalRect"
        guard let data = extendedAttribute(named: attributeName, at: url),
              let quartzRect = captureRect(fromMetadata: data) else { return nil }
        return appKitRect(fromQuartzRect: quartzRect)
    }

    private static func extendedAttribute(named name: String, at url: URL) -> Data? {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return nil }
            return name.withCString { attributeName in
                let length = getxattr(path, attributeName, nil, 0, 0, 0)
                guard length > 0 else { return nil }

                var data = Data(count: length)
                let bytesRead = data.withUnsafeMutableBytes { buffer in
                    getxattr(path, attributeName, buffer.baseAddress, length, 0, 0)
                }
                guard bytesRead == length else { return nil }
                return data
            }
        }
    }

    /// Screenshot metadata uses Quartz's top-left desktop coordinates. AppKit
    /// windows use bottom-left coordinates, so convert through the source display.
    private static func appKitRect(fromQuartzRect rect: NSRect) -> NSRect? {
        let candidates = NSScreen.screens.compactMap { screen -> (NSScreen, CGRect)? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return (screen, CGDisplayBounds(CGDirectDisplayID(number.uint32Value)))
        }
        guard let (screen, quartzFrame) = candidates.max(by: {
            intersectionArea(rect, $0.1) < intersectionArea(rect, $1.1)
        }), intersectionArea(rect, quartzFrame) > 0 else { return nil }

        let scaleX = screen.frame.width / quartzFrame.width
        let scaleY = screen.frame.height / quartzFrame.height
        return NSRect(
            x: screen.frame.minX + (rect.minX - quartzFrame.minX) * scaleX,
            y: screen.frame.maxY - (rect.maxY - quartzFrame.minY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}

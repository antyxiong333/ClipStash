import AppKit
import Foundation

/// Uses macOS built-in `screencapture -i` (same as Cmd+Shift+4)
final class ScreenCaptureService {
    var onCapture: ((NSImage) -> Void)?

    func startCapture() {
        let tempPath = NSTemporaryDirectory() + "clipstash-\(UUID().uuidString).png"

        // Run on background thread so the blocking waitUntilExit doesn't freeze UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-i", "-x", "-r", tempPath]

            do {
                try task.run()
                task.waitUntilExit()  // Block until user finishes selection
            } catch {
                print("ClipStash: screencapture failed: \(error)")
                return
            }

            // Back to main thread
            DispatchQueue.main.async {
                guard FileManager.default.fileExists(atPath: tempPath),
                      let image = NSImage(contentsOf: URL(fileURLWithPath: tempPath)),
                      image.size.width > 0 else {
                    try? FileManager.default.removeItem(atPath: tempPath)
                    return
                }

                // Activate app and deliver image
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)

                self?.onCapture?(image)

                // Switch back to accessory after a moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.setActivationPolicy(.accessory)
                }

                try? FileManager.default.removeItem(atPath: tempPath)
            }
        }
    }
}

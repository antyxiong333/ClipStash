import AppKit
import Foundation

@Observable
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    var isInternalCopy = false
    weak var store: ClipboardStore?

    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if isInternalCopy {
            isInternalCopy = false
            return
        }

        if let item = PasteboardReader.read() {
            store?.addItem(item)
        }
    }
}

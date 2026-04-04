import AppKit
import Carbon

final class GlobalKeyboardShortcut {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let toggleAction: () -> Void
    private let screenshotAction: () -> Void

    init(toggleAction: @escaping () -> Void, screenshotAction: @escaping () -> Void) {
        self.toggleAction = toggleAction
        self.screenshotAction = screenshotAction
    }

    /// Register global hotkeys:
    /// - Cmd+Shift+V: toggle panel
    /// - Cmd+Ctrl+S: screenshot
    func register() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }

    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+Shift+V → toggle panel
        if flags == [.command, .shift] && event.keyCode == 9 {
            DispatchQueue.main.async { [weak self] in
                self?.toggleAction()
            }
            return true
        }

        // Cmd+Ctrl+S → screenshot
        if flags == [.command, .control] && event.keyCode == 1 {
            DispatchQueue.main.async { [weak self] in
                self?.screenshotAction()
            }
            return true
        }

        return false
    }

    deinit {
        unregister()
    }
}

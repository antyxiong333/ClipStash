import AppKit
import Carbon

final class GlobalKeyboardShortcut {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    /// Register Cmd+Shift+V as global hotkey
    func register() {
        // Monitor when another app is focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Monitor when our app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // consume the event
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
        // Cmd+Shift+V
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == [.command, .shift] && event.keyCode == 9 { // keyCode 9 = V
            DispatchQueue.main.async { [weak self] in
                self?.action()
            }
            return true
        }
        return false
    }

    deinit {
        unregister()
    }
}

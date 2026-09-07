import AppKit
import Carbon
import OSLog

final class GlobalKeyboardShortcut {
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []
    private let toggleAction: () -> Void
    private let screenshotAction: () -> Void
    private static let signature: OSType = 0x43535448 // CSTH
    private static let logger = Logger(subsystem: "com.clipstash.app", category: "KeyboardShortcuts")

    init(toggleAction: @escaping () -> Void, screenshotAction: @escaping () -> Void) {
        self.toggleAction = toggleAction
        self.screenshotAction = screenshotAction
    }

    /// Register global hotkeys:
    /// - Cmd+Shift+V: toggle panel
    /// - Cmd+Ctrl+S: screenshot
    func register() -> [String] {
        unregister()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                          EventParamType(typeEventHotKeyID), nil,
                                          MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard result == noErr, hotKeyID.signature == GlobalKeyboardShortcut.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let shortcuts = Unmanaged<GlobalKeyboardShortcut>.fromOpaque(context).takeUnretainedValue()
            shortcuts.handleHotKey(hotKeyID.id)
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        guard status == noErr else {
            return ["Could not register keyboard shortcuts (error \(status)). Use the menu bar instead."]
        }

        var errors: [String] = []
        let shortcuts: [(UInt32, UInt32, UInt32, String)] = [
            (UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey), 1, "Cmd+Shift+V"),
            (UInt32(kVK_ANSI_S), UInt32(cmdKey | controlKey), 2, "Cmd+Ctrl+S")
        ]
        for (keyCode, modifiers, id, name) in shortcuts {
            var hotKey: EventHotKeyRef?
            let result = RegisterEventHotKey(keyCode, modifiers,
                                            EventHotKeyID(signature: Self.signature, id: id),
                                            GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &hotKey)
            if result == noErr, let hotKey {
                hotKeys.append(hotKey)
                Self.logger.info("Registered \(name, privacy: .public)")
            } else {
                errors.append("\(name) is unavailable (error \(result)). Another app may be using it. Use the menu bar instead.")
                Self.logger.error("Could not register \(name, privacy: .public): \(result)")
            }
        }
        return errors
    }

    func unregister() {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
    }

    private func handleHotKey(_ id: UInt32) {
        DispatchQueue.main.async { [weak self] in
            switch id {
            case 1:
                self?.toggleAction()
            case 2:
                self?.screenshotAction()
            default:
                break
            }
        }
    }

    deinit {
        unregister()
    }
}

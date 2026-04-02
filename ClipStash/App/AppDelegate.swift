import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let store = ClipboardStore()
    let monitor = ClipboardMonitor()
    let panelController = FloatingPanelController()
    var keyboardShortcut: GlobalKeyboardShortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)

        // Wire up store and monitor
        monitor.store = store
        store.monitor = monitor

        // Load history from disk
        store.loadFromDisk()

        // Start monitoring clipboard
        monitor.start()

        // Setup floating panel with SwiftUI view
        let contentView = ClipboardListView(store: store)
        panelController.setupPanel(with: contentView)
        panelController.show()

        // Setup menu bar icon
        setupStatusItem()

        // Setup global keyboard shortcut (Cmd+Shift+V)
        keyboardShortcut = GlobalKeyboardShortcut { [weak self] in
            self?.panelController.toggle()
        }
        keyboardShortcut?.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        keyboardShortcut?.unregister()
        PersistenceManager.save(items: store.items)
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipStash")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Show/Hide Panel", action: #selector(togglePanel), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ClipStash", action: #selector(quitApp), keyEquivalent: "q")
            .target = self

        statusItem.menu = menu
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }

    @objc private func clearHistory() {
        store.clearAll()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

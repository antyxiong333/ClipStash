import AppKit
import SwiftUI

let appVersion = "1.1.0"

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let store = ClipboardStore()
    let monitor = ClipboardMonitor()
    let panelController = FloatingPanelController()
    var keyboardShortcut: GlobalKeyboardShortcut?
    let captureService = ScreenCaptureService()
    var editorWindow: ScreenshotEditorWindow?
    var floatingScreenshots: [ScreenshotFloatingWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor.store = store
        store.monitor = monitor
        store.onScreenshot = { [weak self] in self?.startScreenshot() }
        store.onPinImage = { [weak self] item in self?.pinImageItem(item) }

        store.loadFromDisk()
        monitor.start()

        let contentView = ClipboardListView(store: store)
        panelController.setupPanel(with: contentView)
        panelController.show()

        setupStatusItem()

        keyboardShortcut = GlobalKeyboardShortcut(
            toggleAction: { [weak self] in self?.panelController.toggle() },
            screenshotAction: { [weak self] in self?.startScreenshot() }
        )
        keyboardShortcut?.register()

        // Wire up capture service
        captureService.onCapture = { [weak self] image in
            self?.showEditor(for: image)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        keyboardShortcut?.unregister()
        PersistenceManager.save(items: store.items)
    }

    // MARK: - Screenshot

    func startScreenshot() {
        panelController.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.captureService.startCapture()
        }
    }

    private func showEditor(for image: NSImage) {
        editorWindow = ScreenshotEditorWindow(
            image: image,
            onSave: { [weak self] finalImage in
                self?.saveScreenshot(finalImage)
                self?.editorWindow = nil
                self?.panelController.show()
            },
            onCancel: { [weak self] in
                self?.editorWindow = nil
                self?.panelController.show()
            },
            onPin: { [weak self] finalImage in
                self?.saveScreenshot(finalImage)
                self?.pinImage(finalImage)
                self?.editorWindow = nil
                self?.panelController.show()
            }
        )
        NSApp.activate(ignoringOtherApps: true)
        editorWindow?.makeKeyAndOrderFront(nil)
    }

    private func saveScreenshot(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

        let item = ClipboardItem(
            contentType: .image,
            imageData: pngData,
            sourceAppName: "ClipStash Screenshot"
        )
        store.addItem(item)

        monitor.isInternalCopy = true
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(pngData, forType: .png)
    }

    private func pinImage(_ image: NSImage) {
        let floatingWindow = ScreenshotFloatingWindow(image: image)
        floatingWindow.onClose = { [weak self, weak floatingWindow] in
            self?.floatingScreenshots.removeAll { $0 === floatingWindow }
        }
        floatingWindow.makeKeyAndOrderFront(nil)
        floatingScreenshots.append(floatingWindow)
    }

    private func pinImageItem(_ item: ClipboardItem) {
        guard let data = item.imageData, let image = NSImage(data: data) else { return }
        pinImage(image)
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

        // Version header
        let versionItem = NSMenuItem(title: "ClipStash v\(appVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())

        menu.addItem(withTitle: "Show/Hide Panel", action: #selector(togglePanel), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Screenshot", action: #selector(takeScreenshot), keyEquivalent: "")
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

    @objc private func takeScreenshot() {
        startScreenshot()
    }

    @objc private func clearHistory() {
        store.clearAll()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

import AppKit
import Combine
import SwiftUI

let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3.0"

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let store = ClipboardStore()
    let monitor = ClipboardMonitor()
    let panelController = FloatingPanelController()
    var keyboardShortcut: GlobalKeyboardShortcut?
    let captureService = ScreenCaptureService()
    let meetingAssistant = MeetingAssistantService()
    var editorWindow: ScreenshotEditorWindow?
    var meetingCaptionWindow: MeetingCaptionWindow?
    var floatingScreenshots: [ScreenshotFloatingWindow] = []
    private var restorePanelAfterCapture = false
    private var displayLanguageCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor.store = store
        store.monitor = monitor
        store.onScreenshot = { [weak self] in self?.startScreenshot() }
        store.onPinImage = { [weak self] item in self?.pinImageItem(item) }

        store.loadFromDisk()
        monitor.start()

        let contentView = ClipboardListView(store: store, onToggleMeeting: { [weak self] in
            self?.toggleMeetingCaptions()
        })
        panelController.setupPanel(with: contentView)
        panelController.show()

        setupStatusItem()

        keyboardShortcut = GlobalKeyboardShortcut(
            toggleAction: { [weak self] in self?.panelController.toggle() },
            screenshotAction: { [weak self] in self?.startScreenshot() }
        )
        store.shortcutErrors = keyboardShortcut?.register() ?? []

        // Wire up capture service
        captureService.onCompletion = { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .captured(let screenshot):
                self.showEditor(for: screenshot)
            case .cancelled:
                if self.restorePanelAfterCapture { self.panelController.show() }
            case .failed(let failure):
                self.panelController.show()
                self.showScreenshotFailure(failure)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        keyboardShortcut?.unregister()
        PersistenceManager.save(items: store.items)
    }

    // MARK: - Screenshot

    func startScreenshot() {
        guard !captureService.isCapturing else { return }
        if let editorWindow, editorWindow.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            editorWindow.makeKeyAndOrderFront(nil)
            return
        }
        restorePanelAfterCapture = panelController.isVisible
        panelController.hide()
        captureService.startCapture()
    }

    private func showScreenshotFailure(_ failure: ScreenCaptureFailure) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        switch failure {
        case .permissionRequired:
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "Allow this copy of ClipStash in System Settings > Privacy & Security > Screen & System Audio Recording, then quit and reopen it. An older copy's permission may not apply.\n\nRunning app: \(Bundle.main.bundlePath)"
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
        case .couldNotStart:
            alert.messageText = "Could Not Start Screenshot"
            alert.informativeText = "macOS could not launch the screenshot tool. Reopen ClipStash and try again."
            alert.addButton(withTitle: "OK")
        case .commandFailed(let status):
            alert.messageText = "Screenshot Failed"
            alert.informativeText = "The system screenshot tool returned error \(status). Check Screen Recording permission for this copy of ClipStash, then reopen the app."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
        case .invalidImage:
            alert.messageText = "Could Not Read Screenshot"
            alert.informativeText = "The screenshot did not contain a valid image. Please try again."
            alert.addButton(withTitle: "OK")
        }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            switch failure {
            case .permissionRequired, .commandFailed:
                ScreenCaptureService.openPermissionSettings()
            default:
                break
            }
        }
    }

    private func showEditor(for screenshot: CapturedScreenshot) {
        editorWindow = ScreenshotEditorWindow(
            image: screenshot.image,
            captureRect: screenshot.screenRect,
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
                self?.pinImage(finalImage, sourceRect: screenshot.screenRect)
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

    private func pinImage(_ image: NSImage, sourceRect: NSRect? = nil) {
        let floatingWindow = ScreenshotFloatingWindow(image: image, sourceRect: sourceRect)
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

    private func toggleMeetingCaptions() {
        if let meetingCaptionWindow, meetingCaptionWindow.isVisible {
            meetingCaptionWindow.close()
            self.meetingCaptionWindow = nil
            return
        }

        let window = MeetingCaptionWindow(service: meetingAssistant)
        meetingCaptionWindow = window
        window.makeKeyAndOrderFront(nil)
        meetingAssistant.start()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipStash")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        // NSMenu titles are not SwiftUI views, so rebuild this menu whenever
        // the shared display-language preference changes.
        displayLanguageCancellable = DisplayLanguageSettings.shared.$language
            .sink { [weak self] _ in self?.updateStatusMenu() }
    }

    private func updateStatusMenu() {
        let menu = NSMenu()
        let isChinese = DisplayLanguageSettings.shared.language == .chinese

        // Version header
        let versionItem = NSMenuItem(title: "ClipStash v\(appVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())

        menu.addItem(withTitle: isChinese ? "显示/隐藏面板" : "Show/Hide Panel", action: #selector(togglePanel), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: isChinese ? "截图" : "Screenshot", action: #selector(takeScreenshot), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: isChinese ? "清除历史记录" : "Clear History", action: #selector(clearHistory), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: isChinese ? "退出 ClipStash" : "Quit ClipStash", action: #selector(quitApp), keyEquivalent: "q")
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

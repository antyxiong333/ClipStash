import AppKit
import SwiftUI

/// Window that hosts the screenshot editor
class ScreenshotEditorWindow: NSPanel {
    init(image: NSImage, onSave: @escaping (NSImage) -> Void, onCancel: @escaping () -> Void, onPin: ((NSImage) -> Void)?) {
        // Size the window to fit the image with some padding for toolbar
        let maxWidth: CGFloat = 900
        let maxHeight: CGFloat = 700
        let ratio = min(maxWidth / image.size.width, maxHeight / image.size.height, 1.0)
        let contentWidth = image.size.width * ratio + 32
        let contentHeight = image.size.height * ratio + 100 // toolbar space

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.title = "Edit Screenshot"
        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.appearance = NSAppearance(named: .aqua)
        self.isOpaque = false
        self.backgroundColor = .white
        self.center()

        let editorView = ScreenshotEditorView(
            originalImage: image,
            onSave: { [weak self] finalImage in
                onSave(finalImage)
                self?.orderOut(nil)
            },
            onCancel: { [weak self] in
                onCancel()
                self?.orderOut(nil)
            },
            onPin: onPin != nil ? { [weak self] finalImage in
                onPin?(finalImage)
                self?.orderOut(nil)
            } : nil
        )

        let hostingView = NSHostingView(rootView: editorView)
        self.contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

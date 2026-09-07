import AppKit
import SwiftUI

/// Window that hosts the screenshot editor
class ScreenshotEditorWindow: NSPanel {
    init(image: NSImage, captureRect: NSRect?, onSave: @escaping (NSImage) -> Void, onCancel: @escaping () -> Void, onPin: ((NSImage) -> Void)?) {
        let screen = Self.screen(containing: captureRect) ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        // Native screenshot metadata is expressed in screen points, while the
        // PNG keeps Retina pixels. Use the former for the window and the latter
        // for editing/export quality.
        let editorFrame = Self.editorFrame(
            imageSize: image.size,
            captureRect: captureRect,
            visibleFrame: visibleFrame
        )
        let editorContentRect = NSWindow.contentRect(forFrameRect: editorFrame, styleMask: styleMask)

        super.init(
            contentRect: editorContentRect,
            styleMask: styleMask,
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
        self.minSize = NSSize(width: 360, height: 300)
        self.animationBehavior = .documentWindow
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

    static func editorFrame(imageSize: NSSize, captureRect: NSRect?, visibleFrame: NSRect) -> NSRect {
        let minimumFrameSize = NSSize(width: 360, height: 300)
        let maximumFrameSize = NSSize(width: visibleFrame.width - 24, height: visibleFrame.height - 24)
        let preferredFrame = captureRect ?? NSRect(
            x: visibleFrame.midX - (imageSize.width + 32) / 2,
            y: visibleFrame.midY - (imageSize.height + 90) / 2,
            width: imageSize.width + 32,
            height: imageSize.height + 90
        )
        let frameSize = NSSize(
            width: min(max(preferredFrame.width, minimumFrameSize.width), maximumFrameSize.width),
            height: min(max(preferredFrame.height, minimumFrameSize.height), maximumFrameSize.height)
        )
        var editorFrame = NSRect(
            x: preferredFrame.midX - frameSize.width / 2,
            y: preferredFrame.midY - frameSize.height / 2,
            width: frameSize.width,
            height: frameSize.height
        )
        editorFrame.origin.x = min(max(editorFrame.minX, visibleFrame.minX + 12), visibleFrame.maxX - editorFrame.width - 12)
        editorFrame.origin.y = min(max(editorFrame.minY, visibleFrame.minY + 12), visibleFrame.maxY - editorFrame.height - 12)
        return editorFrame
    }

    private static func screen(containing rect: NSRect?) -> NSScreen? {
        guard let rect else { return nil }
        return NSScreen.screens.max {
            $0.frame.intersection(rect).area < $1.frame.intersection(rect).area
        }
    }
}

private extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

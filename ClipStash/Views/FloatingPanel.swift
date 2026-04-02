import AppKit
import SwiftUI

class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentView = contentView
        self.title = "ClipStash"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden

        // Transparent background
        self.isOpaque = false
        self.backgroundColor = NSColor.white.withAlphaComponent(0.001)
        self.appearance = NSAppearance(named: .aqua)

        // Always on top
        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false

        // Visible in all Spaces
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.animationBehavior = .utilityWindow

        // Minimum size
        self.minSize = NSSize(width: 280, height: 300)

        // Position: top-right of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - frame.width - 20
            let y = screenFrame.maxY - frame.height - 20
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    // Allow the panel to become key so text fields work
    override var canBecomeKey: Bool { true }

    // Prevent the panel from becoming main window
    override var canBecomeMain: Bool { false }

    // Close button hides instead of closing
    override func close() {
        orderOut(nil)
    }
}

class FloatingPanelController {
    var panel: FloatingPanel?

    func setupPanel(with view: some View) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 520)
        panel = FloatingPanel(contentView: hostingView)
    }

    func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func show() {
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}

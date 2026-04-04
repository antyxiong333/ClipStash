import AppKit
import SwiftUI

/// Lightweight floating window that displays a pinned screenshot
class ScreenshotFloatingWindow: NSPanel {
    private let screenshotImage: NSImage
    var onClose: (() -> Void)?

    init(image: NSImage) {
        self.screenshotImage = image

        // Scale to reasonable size
        let maxDim: CGFloat = 400
        let ratio = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
        let w = image.size.width * ratio
        let h = image.size.height * ratio

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.title = "Screenshot"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.appearance = NSAppearance(named: .aqua)
        self.isOpaque = false
        self.backgroundColor = NSColor.white.withAlphaComponent(0.95)
        self.hasShadow = true
        self.minSize = NSSize(width: 100, height: 80)

        // Position near center-right
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let x = sf.maxX - w - 40
            let y = sf.midY - h / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        let view = ScreenshotPinnedView(
            image: image,
            onCopy: { [weak self] in self?.copyImage() },
            onClose: { [weak self] in self?.closeWindow() }
        )
        let hostingView = NSHostingView(rootView: view)
        self.contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func close() {
        onClose?()
        orderOut(nil)
    }

    private func copyImage() {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let tiff = screenshotImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            pb.setData(pngData, forType: .png)
        }
    }

    private func closeWindow() {
        onClose?()
        orderOut(nil)
    }
}

// MARK: - Pinned View

struct ScreenshotPinnedView: View {
    let image: NSImage
    let onCopy: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)

            // Overlay buttons on hover
            if isHovered {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Spacer()

                        Button {
                            onCopy()
                            showCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                showCopied = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                Text(showCopied ? "Copied" : "Copy")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

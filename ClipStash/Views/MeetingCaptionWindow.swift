import AppKit
import SwiftUI

final class MeetingCaptionWindow: NSPanel {
    private let service: MeetingAssistantService

    init(service: MeetingAssistantService) {
        self.service = service
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 280),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "ClipStash Live Captions"
        titlebarAppearsTransparent = true
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        minSize = NSSize(width: 500, height: 220)
        contentView = NSHostingView(rootView: MeetingCaptionView(service: service))

        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        if let visibleFrame = screen?.visibleFrame {
            setFrameOrigin(NSPoint(x: visibleFrame.midX - frame.width / 2, y: visibleFrame.minY + 36))
        }

        // SwiftUI may enlarge the hosting view after the panel is created.
        // Re-clamp on the next layout pass so controls never end up off-screen.
        DispatchQueue.main.async { [weak self] in
            self?.keepOnScreen()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func close() {
        service.stop()
        super.close()
    }

    private func keepOnScreen() {
        let screen = NSScreen.screens.max {
            $0.frame.intersection(frame).area < $1.frame.intersection(frame).area
        } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        let margin: CGFloat = 16
        var correctedFrame = frame
        correctedFrame.size.width = min(correctedFrame.width, visibleFrame.width - margin * 2)
        correctedFrame.size.height = min(correctedFrame.height, visibleFrame.height - margin * 2)
        correctedFrame.origin.x = min(max(correctedFrame.minX, visibleFrame.minX + margin), visibleFrame.maxX - correctedFrame.width - margin)
        correctedFrame.origin.y = min(max(correctedFrame.minY, visibleFrame.minY + margin), visibleFrame.maxY - correctedFrame.height - margin)
        setFrame(correctedFrame, display: true)
    }
}

private extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

private struct MeetingCaptionView: View {
    @ObservedObject var service: MeetingAssistantService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(service.isRunning ? "Live captions" : "Captions paused", systemImage: service.isRunning ? "waveform" : "pause.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(service.isRunning ? .green : .secondary)
                Spacer()
                Button(service.isRunning ? "Stop" : "Start") {
                    service.isRunning ? service.stop() : service.start()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    CaptionBlock(title: "English", text: service.transcript, emphasized: true)
                    Divider()
                    CaptionBlock(
                        title: "中文翻译",
                        text: service.translation.isEmpty ? "正在实时翻译…" : service.translation,
                        emphasized: false
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                MeetingHintsView(service: service)
                    .frame(width: 210, alignment: .topLeading)
            }

            Text(service.statusMessage)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
    }
}

private struct CaptionBlock: View {
    let title: String
    let text: String
    let emphasized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: emphasized ? 16 : 14, weight: emphasized ? .medium : .regular))
                .foregroundStyle(emphasized ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MeetingHintsView: View {
    @ObservedObject var service: MeetingAssistantService

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Hints", systemImage: "lightbulb")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if !service.correctionSuggestion.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested correction")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(service.correctionSuggestion)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                    Button("Use correction") { service.acceptCorrection() }
                        .controlSize(.small)
                }
                .padding(8)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            if !service.contextTerms.isEmpty {
                Label(service.contextTerms.joined(separator: " · "), systemImage: "tag")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if !service.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Action items")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(service.actionItems, id: \.self) { item in
                        Text("• \(item)").font(.system(size: 11))
                    }
                }
            }

            if service.correctionSuggestion.isEmpty && service.contextTerms.isEmpty && service.actionItems.isEmpty {
                Text("Terms, corrections, and action items will appear here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

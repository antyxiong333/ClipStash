import AppKit
import SwiftUI

final class MeetingCaptionWindow: NSPanel {
    private let service: MeetingAssistantService

    init(service: MeetingAssistantService) {
        self.service = service
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 420),
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
        minSize = NSSize(width: 620, height: 300)
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
    @ObservedObject private var displayLanguage = DisplayLanguageSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(service.isRunning ? t("实时字幕", "Live captions") : t("字幕已暂停", "Captions paused"), systemImage: service.isRunning ? "waveform" : "pause.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(service.isRunning ? .green : .secondary)
                Spacer()
                Button(service.isRunning ? t("停止", "Stop") : t("开始", "Start")) {
                    service.isRunning ? service.stop() : service.start()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Picker(t("模式", "Mode"), selection: Binding(
                get: { service.meetingMode },
                set: { service.setMeetingMode($0) }
            )) {
                ForEach(MeetingLanguageSettings.Mode.allCases) { mode in
                    Text(mode.displayName(for: displayLanguage.language)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 245, alignment: .leading)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    CaptionSections(service: service)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                ScrollView {
                    MeetingHintsView(service: service)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(minWidth: 160, idealWidth: 190, maxWidth: 210)
            }
            .frame(maxHeight: .infinity)

            Text(service.statusMessage)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
    }

    private func t(_ chinese: String, _ english: String) -> String { displayLanguage.text(chinese, english) }
}

private struct CaptionSections: View {
    @ObservedObject var service: MeetingAssistantService
    @ObservedObject private var displayLanguage = DisplayLanguageSettings.shared
    @State private var followLatest = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(t("跟随最新段落", "Follow latest"), isOn: $followLatest)
                .toggleStyle(.checkbox).font(.system(size: 11))
            section(title: t("原文", "Source"), translated: false)
            Divider()
            section(title: t("译文", "Translation"), translated: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .transaction { $0.animation = nil }
    }

    private func section(title: String, translated: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if service.captionTimeline.rows.isEmpty {
                            Text(translated ? t("等待翻译…", "Waiting for translation…") : t("等待语音…", "Waiting for speech…")).foregroundStyle(.secondary)
                        }
                        ForEach(service.captionTimeline.rows) { pair in
                            VStack(alignment: .leading, spacing: 7) {
                                if !translated {
                                    // Keep the source line paired with the exact snapshot used
                                    // for the translation. `source` may already contain a newer
                                    // speech-recognition revision while the model is still
                                    // translating the previous one.
                                    CaptionWordFlow(text: pair.displayedSource) { word in
                                        service.lookUpWord(word, in: pair.displayedSource)
                                    }
                                } else if !pair.translation.isEmpty {
                                    Text(pair.translation).font(.system(size: 14))
                                } else if !pair.preview.isEmpty {
                                    Text(pair.preview).font(.system(size: 14)).foregroundStyle(.secondary)
                                } else {
                                    Text(t("等待翻译…", "Waiting for translation…")).font(.system(size: 12)).foregroundStyle(.secondary)
                                }
                                if translated, let error = pair.error {
                                    Text(error).font(.system(size: 11)).foregroundStyle(.orange)
                                }
                            }
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(pair.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.trailing, 8)
                }
                .onChange(of: service.captionTimeline.rows.count) { _, _ in
                    if followLatest { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: service.captionTimeline.rows.last?.translation) { _, _ in
                    if followLatest { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: service.captionTimeline.rows.last?.source) { _, _ in
                    if followLatest && !translated { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: followLatest) { _, follow in
                    if follow { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func t(_ chinese: String, _ english: String) -> String { displayLanguage.text(chinese, english) }
}

private struct CaptionWordFlow: View {
    let text: String
    let onWordClick: (String) -> Void

    var body: some View {
        FlowLayout(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                Button(word) { onWordClick(word.trimmingCharacters(in: .punctuationCharacters)) }
                    .buttonStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .contentShape(Rectangle())
                    .help("Click for translation and meaning")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var words: [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }
}

private struct FlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + horizontalSpacing + size.width > maxWidth {
                y += rowHeight + verticalSpacing
                x = 0
                rowHeight = 0
            }
            if x > 0 { x += horizontalSpacing }
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + horizontalSpacing + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            if x > bounds.minX { x += horizontalSpacing }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
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
    @ObservedObject private var displayLanguage = DisplayLanguageSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(t("提示", "Hints"), systemImage: "lightbulb")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if !service.wordHints.isEmpty {
                HStack {
                    Text(t("词典", "Dictionary"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(t("清除", "Clear")) { service.clearWordHints() }
                        .controlSize(.mini)
                }
                ForEach(service.wordHints) { hint in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hint.word)
                            .font(.system(size: 13, weight: .semibold))
                        if hint.isLoading {
                            Text(t("正在查询翻译…", "Looking up translation…"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(hint.detail)
                                .font(.system(size: 11))
                                .textSelection(.enabled)
                        }
                    }
                    .padding(8)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }

            if service.meetingMode != .automatic {
                Text(service.meetingMode == .meeting ? t("会议提示", "Meeting insights") : t("视频提示", "Video insights"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if !service.correctionSuggestion.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("建议纠错", "Suggested correction"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(service.correctionSuggestion)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                    Button(t("使用纠错", "Use correction")) { service.acceptCorrection() }
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
                    Text(service.meetingMode == .video ? t("关键要点", "Key takeaways") : t("行动项", "Action items"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(service.actionItems, id: \.self) { item in
                        Text("• \(item)").font(.system(size: 11))
                    }
                }
            }

            if service.wordHints.isEmpty && service.correctionSuggestion.isEmpty && service.contextTerms.isEmpty && service.actionItems.isEmpty {
                Text(emptyHintMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyHintMessage: String {
        switch service.meetingMode {
        case .automatic:
            return t("点击单词，在这里添加词典翻译。", "Click a word to add its dictionary translation here.")
        case .meeting:
            return t("术语、纠错、决定和行动项将显示在这里。", "Terms, corrections, decisions, and action items will appear here.")
        case .video:
            return t("术语、概念提示和关键要点将显示在这里。", "Terms, concept notes, and key takeaways will appear here.")
        }
    }

    private func t(_ chinese: String, _ english: String) -> String { displayLanguage.text(chinese, english) }
}

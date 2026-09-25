import SwiftUI

struct ClipboardListView: View {
    @Bindable var store: ClipboardStore
    let onToggleMeeting: () -> Void

    @State private var showClearConfirmation = false
    @State private var copiedItemId: UUID?
    @State private var isHovered = false
    @State private var showSettings = false
    @State private var launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
    @State private var launchAtLoginStatus = LaunchAtLoginManager.statusDescription
    @State private var launchAtLoginError: String?
    @State private var screenRecordingAllowed = ScreenCaptureService.hasPermission
    @State private var openAIKey = AISettings.openAIAPIKey() ?? ""
    @State private var huggingFaceToken = AISettings.huggingFaceAccessToken() ?? ""
    @State private var apiKeyStatus: String?
    @State private var glossaryText = MeetingGlossary.text
    @State private var sourceLanguage = MeetingLanguageSettings.source
    @State private var targetLanguage = MeetingLanguageSettings.target
    @State private var assistantMode = MeetingLanguageSettings.mode
    @State private var glossaryExpanded = false
    @ObservedObject private var localModel = LocalModelManager.shared
    @ObservedObject private var displayLanguage = DisplayLanguageSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().opacity(isHovered ? 1 : 0.3)

            // List / Settings
            if showSettings {
                settingsView
            } else if store.filteredItems.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        .frame(minWidth: 280, minHeight: 300)
        .opacity(isHovered ? 1.0 : 0.15)
        .background {
            if isHovered {
                Color.white.opacity(0.95)
            }
        }
        .environment(\.colorScheme, .light)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ClipStash")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(store.items.count) \(t("项", "items"))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                // Search
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField(t("搜索…", "Search..."), text: $store.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !store.searchQuery.isEmpty {
                        Button {
                            store.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Screenshot
                Button {
                    store.onScreenshot?()
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(t("全局截图 (Cmd+Ctrl+S)", "Global Screenshot (Cmd+Ctrl+S)"))
                .accessibilityLabel(t("截图", "Screenshot"))

                Button(action: onToggleMeeting) {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(t("启动实时会议字幕", "Start live meeting captions"))
                .accessibilityLabel(t("实时会议字幕", "Live meeting captions"))

                // Pin filter
                Button {
                    store.showPinnedOnly.toggle()
                } label: {
                    Image(systemName: store.showPinnedOnly ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(store.showPinnedOnly ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(t("仅显示置顶内容", "Show pinned only"))

                // Settings
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showSettings.toggle()
                    }
                    refreshLaunchAtLoginStatus()
                } label: {
                    Image(systemName: showSettings ? "list.bullet" : "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(showSettings ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .help(showSettings ? t("返回剪贴板", "Back to clipboard") : t("设置", "Settings"))

                // Clear all
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(t("清除所有未置顶内容", "Clear all unpinned items"))
                .alert(t("清除历史记录", "Clear History"), isPresented: $showClearConfirmation) {
                    Button(t("取消", "Cancel"), role: .cancel) {}
                    Button(t("清除", "Clear"), role: .destructive) {
                        store.clearAll()
                    }
                } message: {
                    Text(t("确定移除所有未置顶的剪贴板内容吗？已置顶内容会保留。", "Remove all unpinned clipboard items? Pinned items will be kept."))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 20)
    }

    // MARK: - Settings

    private var settingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(t("设置", "Settings"), systemImage: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                    Text(t("在这台 Mac 上设置字幕、翻译和 ClipStash。", "Set up captions, translation, and ClipStash on this Mac."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                SettingsCard(title: t("实时字幕", "Live captions"), icon: "waveform") {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 8) {
                            Picker(t("原文", "Source"), selection: $sourceLanguage) {
                                ForEach(MeetingLanguageSettings.Language.allCases) { Text($0.displayName).tag($0) }
                            }
                            Picker(t("译文", "Target"), selection: $targetLanguage) {
                                ForEach(MeetingLanguageSettings.Language.allCases) { Text($0.displayName).tag($0) }
                            }
                        }
                        .labelsHidden()
                        .onChange(of: sourceLanguage) { _, _ in MeetingLanguageSettings.save(source: sourceLanguage, target: targetLanguage) }
                        .onChange(of: targetLanguage) { _, _ in MeetingLanguageSettings.save(source: sourceLanguage, target: targetLanguage) }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("助手模式", "Assistant mode")).font(.system(size: 11, weight: .medium))
                            Picker(t("助手模式", "Assistant mode"), selection: $assistantMode) {
                                ForEach(MeetingLanguageSettings.Mode.allCases) { Text($0.displayName(for: displayLanguage.language)).tag($0) }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .onChange(of: assistantMode) { _, mode in MeetingLanguageSettings.save(mode: mode) }
                        }
                        Text(t("自动模式延迟最低；会议模式补充行动项；视频模式补充概念要点。", "Auto keeps captions fastest. Meeting adds actions; Video adds key concepts after a sentence ends."))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Button(t("启动实时字幕", "Start live captions"), action: onToggleMeeting)
                            .controlSize(.small)
                    }
                }

                SettingsCard(title: t("AI 与翻译", "AI & translation"), icon: "sparkles") {
                    VStack(alignment: .leading, spacing: 9) {
                        Picker(t("本地模型", "Local model"), selection: Binding(
                            get: { localModel.selectedModel },
                            set: { localModel.select($0) }
                        )) {
                            ForEach(LocalModelManager.Model.allCases) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                        if localModel.selectedModel.requiresHuggingFaceToken {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(t("Gemma 首次下载需要先接受 Google 许可，并提供 Hugging Face 只读 Token。", "Gemma requires accepting Google's license and a Hugging Face read token for its first download."))
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                                if let accessPage = localModel.selectedModel.accessPage {
                                    Link(t("打开 Gemma 许可页面", "Open Gemma license page"), destination: accessPage)
                                        .font(.system(size: 11))
                                }
                                SecureField(t("Hugging Face Read Token", "Hugging Face Read Token"), text: $huggingFaceToken)
                                    .textFieldStyle(.roundedBorder)
                                Button(t("保存 Token", "Save token")) {
                                    do {
                                        try AISettings.saveHuggingFaceAccessToken(huggingFaceToken)
                                        apiKeyStatus = t("Hugging Face Token 已安全保存。", "Hugging Face token saved securely.")
                                    } catch { apiKeyStatus = error.localizedDescription }
                                }
                                .controlSize(.mini)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        HStack(spacing: 6) {
                            Circle().fill(localModel.state == .ready ? Color.green : Color.secondary.opacity(0.45)).frame(width: 7, height: 7)
                            Text(localModel.statusText).font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer()
                            if localModel.state == .ready {
                                Button(t("移除", "Remove")) { localModel.removeDefaultModel() }.controlSize(.small)
                            } else if case .downloading = localModel.state {
                                ProgressView().controlSize(.small)
                            } else {
                                Button(t("下载模型", "Download model")) { localModel.downloadSelectedModel() }.controlSize(.small)
                            }
                        }
                        Toggle(t("使用本地模型", "Use local model"), isOn: $localModel.useLocalModel)
                            .disabled(localModel.state != .ready)
                            .font(.system(size: 12))
                        Text(localModel.selectedModel == .qwen3_4b
                             ? t("Qwen3 使用 ClipStash 内置引擎运行，不需要 Ollama。", "Qwen3 runs through ClipStash’s built-in engine; Ollama is not required.")
                             : t("Gemma 使用 ClipStash 内置 llama.cpp/Metal 引擎运行，不需要 Ollama。", "Gemma runs through ClipStash’s built-in llama.cpp/Metal engine; Ollama is not required."))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                        Divider()
                        SecureField(t("OpenAI API Key（可选）", "OpenAI API key (optional)"), text: $openAIKey)
                            .textFieldStyle(.roundedBorder)
                        Button(t("保存 API Key", "Save API key")) {
                            do {
                                try AISettings.saveOpenAIAPIKey(openAIKey)
                                apiKeyStatus = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "API key removed." : "Saved securely in Keychain."
                            } catch { apiKeyStatus = error.localizedDescription }
                        }
                        .controlSize(.small)
                        DisclosureGroup(t("术语表", "Glossary"), isExpanded: $glossaryExpanded) {
                            VStack(alignment: .leading, spacing: 5) {
                                TextEditor(text: $glossaryText).font(.system(size: 11)).frame(height: 54)
                                    .padding(4).background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 5))
                                HStack {
                                    Text(t("每行一个人名、公司或术语。", "One person, company, or term per line.")).font(.system(size: 10)).foregroundStyle(.secondary)
                                    Spacer()
                                    Button(t("保存", "Save")) { MeetingGlossary.save(text: glossaryText); apiKeyStatus = "Glossary saved." }.controlSize(.mini)
                                }
                            }.padding(.top, 5)
                        }
                        if let apiKeyStatus { Text(apiKeyStatus).font(.system(size: 10)).foregroundStyle(.secondary) }
                    }
                }

                SettingsCard(title: t("权限", "Permissions"), icon: "checkmark.shield") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(screenRecordingAllowed ? t("已允许屏幕录制", "Screen recording allowed") : t("截图需要屏幕录制权限", "Screen recording needed for screenshots"), systemImage: screenRecordingAllowed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 11)).foregroundStyle(screenRecordingAllowed ? Color.green : Color.orange)
                        VStack(alignment: .leading, spacing: 6) {
                            Button(t("屏幕录制", "Screen Recording")) { ScreenCaptureService.openPermissionSettings(); screenRecordingAllowed = ScreenCaptureService.hasPermission }.controlSize(.small)
                            HStack(spacing: 7) {
                                Button(t("麦克风", "Microphone")) { MeetingAssistantService.openMicrophonePrivacySettings() }.controlSize(.small)
                                Button(t("语音识别", "Speech")) { MeetingAssistantService.openSpeechRecognitionPrivacySettings() }.controlSize(.small)
                            }
                        }
                        Text(t("修改隐私权限后，请退出并重新打开 ClipStash。", "After changing a privacy permission, quit and reopen ClipStash.")).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }

                SettingsCard(title: t("系统", "System"), icon: "macbook") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(t("显示语言", "Display language"), selection: Binding(get: { displayLanguage.language }, set: { displayLanguage.set($0) })) {
                            ForEach(DisplayLanguageSettings.Language.allCases) { Text($0.optionLabel).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Toggle(t("登录时启动", "Launch at login"), isOn: Binding(get: { launchAtLoginEnabled }, set: { setLaunchAtLogin($0) }))
                            .toggleStyle(.switch).font(.system(size: 12))
                        Text(launchAtLoginStatus).font(.system(size: 10)).foregroundStyle(.secondary)
                        if let launchAtLoginError { Text(launchAtLoginError).font(.system(size: 10)).foregroundStyle(.red) }
                        Divider()
                        Text(t("截图  ⌘⌃S    •    显示/隐藏  ⌘⇧V", "Screenshot  ⌘⌃S    •    Show/Hide  ⌘⇧V")).font(.system(size: 10)).foregroundStyle(.secondary)
                        ForEach(store.shortcutErrors, id: \.self) { error in Text(error).font(.system(size: 10)).foregroundStyle(.red) }
                    }
                }

                Button {
                    refreshLaunchAtLoginStatus()
                } label: {
                    Label(t("刷新", "Refresh"), systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Text("ClipStash v\(appVersion)\n\(Bundle.main.bundlePath)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .onAppear {
            refreshLaunchAtLoginStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLaunchAtLoginStatus()
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil

        do {
            try LaunchAtLoginManager.setEnabled(enabled)
        } catch {
            launchAtLoginError = error.localizedDescription
        }

        refreshLaunchAtLoginStatus()
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
        launchAtLoginStatus = LaunchAtLoginManager.statusDescription
        screenRecordingAllowed = ScreenCaptureService.hasPermission
    }

    private func t(_ chinese: String, _ english: String) -> String {
        displayLanguage.text(chinese, english)
    }

    // MARK: - List

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(store.filteredItems) { item in
                    ClipboardItemRow(
                        item: item,
                        onCopy: {
                            store.copyToClipboard(item: item)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                copiedItemId = item.id
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                withAnimation {
                                    copiedItemId = nil
                                }
                            }
                        },
                        onTogglePin: {
                            store.togglePin(id: item.id)
                        },
                        onDelete: {
                            withAnimation {
                                store.removeItem(id: item.id)
                            }
                        },
                        onPinFloat: item.contentType == .image ? {
                            store.onPinImage?(item)
                        } : nil
                    )
                    .overlay {
                        if copiedItemId == item.id {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.green.opacity(0.15))
                                .overlay {
                                    Text(t("已复制", "Copied!"))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.green)
                                }
                        }
                    }

                    if item.id != store.filteredItems.last?.id {
                        Divider().padding(.leading, 46)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(store.searchQuery.isEmpty ? t("还没有剪贴板记录", "No clipboard history yet") : t("没有匹配内容", "No matching items"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(t("复制任意内容即可开始", "Copy something to get started"))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.045))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

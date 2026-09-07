import SwiftUI

struct ClipboardListView: View {
    @Bindable var store: ClipboardStore

    @State private var showClearConfirmation = false
    @State private var copiedItemId: UUID?
    @State private var isHovered = false
    @State private var showSettings = false
    @State private var launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
    @State private var launchAtLoginStatus = LaunchAtLoginManager.statusDescription
    @State private var launchAtLoginError: String?
    @State private var screenRecordingAllowed = ScreenCaptureService.hasPermission

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
                Text("\(store.items.count) items")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                // Search
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("Search...", text: $store.searchQuery)
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
                .help("Global Screenshot (Cmd+Ctrl+S)")
                .accessibilityLabel("Screenshot")

                // Pin filter
                Button {
                    store.showPinnedOnly.toggle()
                } label: {
                    Image(systemName: store.showPinnedOnly ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(store.showPinnedOnly ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help("Show pinned only")

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
                .help(showSettings ? "Back to clipboard" : "Settings")

                // Clear all
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear all unpinned items")
                .alert("Clear History", isPresented: $showClearConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        store.clearAll()
                    }
                } message: {
                    Text("Remove all unpinned clipboard items? Pinned items will be kept.")
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
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Settings")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: Binding(
                        get: { launchAtLoginEnabled },
                        set: { setLaunchAtLogin($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Launch at login")
                                .font(.system(size: 13, weight: .medium))
                            Text("Open ClipStash automatically when you sign in.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(launchAtLoginEnabled ? Color.green : Color.secondary.opacity(0.45))
                            .frame(width: 6, height: 6)
                        Text("Status: \(launchAtLoginStatus)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    if let launchAtLoginError {
                        Text(launchAtLoginError)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Screen Recording")
                        .font(.system(size: 13, weight: .medium))
                    Label(screenRecordingAllowed ? "Allowed" : "Permission required for screenshots",
                          systemImage: screenRecordingAllowed ? "checkmark.circle" : "exclamationmark.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(screenRecordingAllowed ? Color.green : Color.orange)
                    Button("Open System Settings") {
                        ScreenCaptureService.openPermissionSettings()
                        screenRecordingAllowed = ScreenCaptureService.hasPermission
                    }
                    .font(.system(size: 12))
                    Text("After allowing access, quit and reopen this copy of ClipStash.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 13, weight: .medium))
                    Text("Global Screenshot: Cmd+Ctrl+S\nShow/Hide Panel: Cmd+Shift+V")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    ForEach(store.shortcutErrors, id: \.self) { error in
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    refreshLaunchAtLoginStatus()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
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
                                    Text("Copied!")
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
            Text(store.searchQuery.isEmpty ? "No clipboard history yet" : "No matching items")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Copy something to get started")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}

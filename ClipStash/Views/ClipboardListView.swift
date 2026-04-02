import SwiftUI

struct ClipboardListView: View {
    @Bindable var store: ClipboardStore

    @State private var showClearConfirmation = false
    @State private var copiedItemId: UUID?
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().opacity(isHovered ? 1 : 0.3)

            // List
            if store.filteredItems.isEmpty {
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
                        }
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

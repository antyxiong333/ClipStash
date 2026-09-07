import AppKit
import Foundation

@Observable
final class ClipboardStore {
    var items: [ClipboardItem] = []
    var searchQuery: String = ""
    var showPinnedOnly: Bool = false
    var shortcutErrors: [String] = []
    let maxHistorySize = 200

    weak var monitor: ClipboardMonitor?
    var onScreenshot: (() -> Void)?
    var onPinImage: ((ClipboardItem) -> Void)?

    var filteredItems: [ClipboardItem] {
        var result = items
        if showPinnedOnly {
            result = result.filter(\.isPinned)
        }
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { item in
                if let text = item.textContent?.lowercased(), text.contains(query) {
                    return true
                }
                if item.contentType.label.lowercased().contains(query) {
                    return true
                }
                if let app = item.sourceAppName?.lowercased(), app.contains(query) {
                    return true
                }
                return false
            }
        }
        return result
    }

    func addItem(_ item: ClipboardItem) {
        // Duplicate detection
        if let first = items.first, first.contentHash == item.contentHash {
            return
        }
        items.insert(item, at: 0)
        // Trim non-pinned items if over max
        while items.count > maxHistorySize {
            if let lastUnpinnedIndex = items.lastIndex(where: { !$0.isPinned }) {
                items.remove(at: lastUnpinnedIndex)
            } else {
                break
            }
        }
        PersistenceManager.scheduleSave(items: items)
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        PersistenceManager.scheduleSave(items: items)
    }

    func clearAll() {
        items.removeAll { !$0.isPinned }
        PersistenceManager.scheduleSave(items: items)
    }

    func togglePin(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isPinned.toggle()
            PersistenceManager.scheduleSave(items: items)
        }
    }

    func copyToClipboard(item: ClipboardItem) {
        monitor?.isInternalCopy = true
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.contentType {
        case .plainText, .webURL:
            if let text = item.textContent {
                pb.setString(text, forType: .string)
            }
        case .richText:
            if let rtfData = item.richTextData {
                pb.setData(rtfData, forType: .rtf)
            }
            if let text = item.textContent {
                pb.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imageData {
                pb.setData(data, forType: .png)
            }
        case .fileURL:
            if let urls = item.fileURLs {
                let nsURLs = urls.compactMap { URL(string: $0) as NSURL? }
                pb.writeObjects(nsURLs)
            }
        case .other:
            if let text = item.textContent {
                pb.setString(text, forType: .string)
            }
        }
    }

    func loadFromDisk() {
        items = PersistenceManager.load()
    }
}

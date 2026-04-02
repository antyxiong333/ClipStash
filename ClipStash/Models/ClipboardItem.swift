import AppKit
import Foundation

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let contentType: ContentType
    let textContent: String?
    let richTextData: Data?
    let imageData: Data?
    let fileURLs: [String]?
    let timestamp: Date
    var isPinned: Bool
    let sourceAppName: String?

    init(
        contentType: ContentType,
        textContent: String? = nil,
        richTextData: Data? = nil,
        imageData: Data? = nil,
        fileURLs: [String]? = nil,
        sourceAppName: String? = nil
    ) {
        self.id = UUID()
        self.contentType = contentType
        self.textContent = textContent
        self.richTextData = richTextData
        self.imageData = imageData
        self.fileURLs = fileURLs
        self.timestamp = Date()
        self.isPinned = false
        self.sourceAppName = sourceAppName
    }

    var displayTitle: String {
        switch contentType {
        case .plainText, .richText, .webURL:
            if let text = textContent {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count > 100 {
                    return String(trimmed.prefix(100)) + "..."
                }
                return trimmed
            }
            return contentType.label
        case .image:
            return "Image"
        case .fileURL:
            if let urls = fileURLs {
                let names = urls.compactMap { URL(string: $0)?.lastPathComponent }
                return names.joined(separator: ", ")
            }
            return "File"
        case .other:
            return "Other"
        }
    }

    var previewText: String? {
        textContent?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var thumbnailImage: NSImage? {
        guard let data = imageData else { return nil }
        guard let image = NSImage(data: data) else { return nil }
        let maxDim: CGFloat = 60
        let ratio = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
        let newSize = NSSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        thumbnail.unlockFocus()
        return thumbnail
    }

    var contentHash: Int {
        var hasher = Hasher()
        if let text = textContent { hasher.combine(text) }
        if let data = imageData { hasher.combine(data.prefix(1024)) }
        if let urls = fileURLs { hasher.combine(urls) }
        return hasher.finalize()
    }
}

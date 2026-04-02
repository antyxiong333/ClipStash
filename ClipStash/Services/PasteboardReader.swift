import AppKit
import Foundation

enum PasteboardReader {
    static let maxImageSize = 10 * 1024 * 1024 // 10MB

    static func read() -> ClipboardItem? {
        let pb = NSPasteboard.general
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName

        // 1. File URLs
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            return ClipboardItem(
                contentType: .fileURL,
                textContent: urls.map(\.lastPathComponent).joined(separator: ", "),
                fileURLs: urls.map(\.absoluteString),
                sourceAppName: sourceApp
            )
        }

        // 2. Images
        if let imgData = pb.data(forType: .png) ?? pb.data(forType: .tiff) {
            if imgData.count <= maxImageSize {
                // Convert to PNG if it's TIFF
                let pngData: Data?
                if pb.data(forType: .png) != nil {
                    pngData = imgData
                } else if let img = NSImage(data: imgData), let rep = img.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: rep) {
                    pngData = bitmap.representation(using: .png, properties: [:])
                } else {
                    pngData = imgData
                }
                return ClipboardItem(
                    contentType: .image,
                    imageData: pngData,
                    sourceAppName: sourceApp
                )
            } else {
                // Too large, store thumbnail only
                if let img = NSImage(data: imgData), let rep = img.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: rep) {
                    let thumbData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.5])
                    return ClipboardItem(
                        contentType: .image,
                        textContent: "Image (too large to store: \(imgData.count / 1024 / 1024)MB)",
                        imageData: thumbData,
                        sourceAppName: sourceApp
                    )
                }
            }
        }

        // 3. Rich text (RTF)
        if let rtfData = pb.data(forType: .rtf) {
            let plainText = pb.string(forType: .string)
            return ClipboardItem(
                contentType: .richText,
                textContent: plainText,
                richTextData: rtfData,
                sourceAppName: sourceApp
            )
        }

        // 4. URLs
        if let urlString = pb.string(forType: .string),
           let url = URL(string: urlString),
           let scheme = url.scheme,
           ["http", "https", "ftp"].contains(scheme) {
            return ClipboardItem(
                contentType: .webURL,
                textContent: urlString,
                sourceAppName: sourceApp
            )
        }

        // 5. Plain text
        if let text = pb.string(forType: .string), !text.isEmpty {
            return ClipboardItem(
                contentType: .plainText,
                textContent: text,
                sourceAppName: sourceApp
            )
        }

        // 6. Other - check if pasteboard has any content
        if let types = pb.types, !types.isEmpty {
            let typeNames = types.map(\.rawValue).joined(separator: ", ")
            return ClipboardItem(
                contentType: .other,
                textContent: "Unsupported type: \(typeNames)",
                sourceAppName: sourceApp
            )
        }

        return nil
    }
}

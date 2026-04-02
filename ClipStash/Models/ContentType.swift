import Foundation

enum ContentType: String, Codable, CaseIterable {
    case plainText
    case richText
    case image
    case fileURL
    case webURL
    case other

    var icon: String {
        switch self {
        case .plainText: return "doc.text"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .fileURL: return "folder"
        case .webURL: return "link"
        case .other: return "questionmark.square"
        }
    }

    var label: String {
        switch self {
        case .plainText: return "Text"
        case .richText: return "Rich Text"
        case .image: return "Image"
        case .fileURL: return "File"
        case .webURL: return "URL"
        case .other: return "Other"
        }
    }
}

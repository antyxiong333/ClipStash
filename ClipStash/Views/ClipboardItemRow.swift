import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Content type icon
            Image(systemName: item.contentType.icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Content preview
            VStack(alignment: .leading, spacing: 3) {
                // Image thumbnail
                if item.contentType == .image, let img = item.thumbnailImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Text content
                Text(item.displayTitle)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                // Metadata
                HStack(spacing: 6) {
                    Text(item.timestamp, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if let app = item.sourceAppName {
                        Text("from \(app)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 4) {
                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundStyle(item.isPinned ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "Unpin" : "Pin")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(item.isPinned ? Color.yellow.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onCopy()
        }
    }

    private var iconColor: Color {
        switch item.contentType {
        case .plainText: return .blue
        case .richText: return .purple
        case .image: return .green
        case .fileURL: return .orange
        case .webURL: return .cyan
        case .other: return .gray
        }
    }
}

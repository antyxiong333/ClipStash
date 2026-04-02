import Foundation

enum PersistenceManager {
    private static var saveTimer: Timer?
    private static let saveInterval: TimeInterval = 5.0

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ClipStash", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    static func scheduleSave(items: [ClipboardItem]) {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: false) { _ in
            save(items: items)
        }
    }

    static func save(items: [ClipboardItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("ClipStash: Failed to save history: \(error)")
        }
    }

    static func load() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: storageURL)
            return try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            print("ClipStash: Failed to load history: \(error)")
            return []
        }
    }
}

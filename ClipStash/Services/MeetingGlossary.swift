import Foundation

enum MeetingGlossary {
    private static let storageKey = "meetingGlossaryTerms"

    static var text: String {
        terms.joined(separator: "\n")
    }

    static var terms: [String] {
        UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    }

    static func save(text: String) {
        let uniqueTerms = Set(text
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
        UserDefaults.standard.set(uniqueTerms.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, forKey: storageKey)
    }
}

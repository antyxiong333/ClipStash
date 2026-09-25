import Combine
import Foundation

/// Persists one UI language for every ClipStash surface. It is deliberately
/// separate from caption source/target languages, which control AI requests.
final class DisplayLanguageSettings: ObservableObject {
    enum Language: String, CaseIterable, Identifiable {
        case chinese, english

        var id: String { rawValue }
        var optionLabel: String { self == .chinese ? "中文" : "English" }
    }

    static let shared = DisplayLanguageSettings()
    private static let key = "clipStashDisplayLanguage"

    @Published private(set) var language: Language

    private init() {
        language = Language(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .chinese
    }

    func set(_ language: Language) {
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.key)
    }

    func text(_ chinese: String, _ english: String) -> String {
        language == .chinese ? chinese : english
    }
}

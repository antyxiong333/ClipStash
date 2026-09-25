import Foundation

enum MeetingLanguageSettings {
    enum Mode: String, CaseIterable, Identifiable {
        case automatic = "Auto", meeting = "Meeting", video = "Video"
        var id: String { rawValue }
        func displayName(for language: DisplayLanguageSettings.Language) -> String {
            switch (self, language) {
            case (.automatic, .chinese): return "自动"
            case (.meeting, .chinese): return "会议"
            case (.video, .chinese): return "视频"
            case (.automatic, .english): return "Auto"
            case (.meeting, .english): return "Meeting"
            case (.video, .english): return "Video"
            }
        }
    }

    enum Language: String, CaseIterable, Identifiable {
        case english = "English", chinese = "Simplified Chinese", japanese = "Japanese", korean = "Korean", spanish = "Spanish", french = "French", german = "German"
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .english: return "英语 English"
            case .chinese: return "简体中文 Simplified Chinese"
            case .japanese: return "日语 Japanese"
            case .korean: return "韩语 Korean"
            case .spanish: return "西班牙语 Spanish"
            case .french: return "法语 French"
            case .german: return "德语 German"
            }
        }
        var speechLocale: String {
            switch self { case .english: return "en-US"; case .chinese: return "zh-CN"; case .japanese: return "ja-JP"; case .korean: return "ko-KR"; case .spanish: return "es-ES"; case .french: return "fr-FR"; case .german: return "de-DE" }
        }
    }
    private static let sourceKey = "meetingSourceLanguage"
    private static let targetKey = "meetingTargetLanguage"
    private static let modeKey = "meetingAssistantMode"
    static var source: Language { Language(rawValue: UserDefaults.standard.string(forKey: sourceKey) ?? "") ?? .english }
    static var target: Language { Language(rawValue: UserDefaults.standard.string(forKey: targetKey) ?? "") ?? .chinese }
    static var mode: Mode { Mode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .automatic }
    static func save(source: Language, target: Language) { UserDefaults.standard.set(source.rawValue, forKey: sourceKey); UserDefaults.standard.set(target.rawValue, forKey: targetKey) }
    static func save(mode: Mode) { UserDefaults.standard.set(mode.rawValue, forKey: modeKey) }
}

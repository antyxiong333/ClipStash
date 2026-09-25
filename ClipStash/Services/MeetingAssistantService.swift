import AppKit
import AVFoundation
import Combine
import Foundation
import Speech

struct WordHint: Identifiable {
    let id: UUID
    let word: String
    var detail: String
    var isLoading: Bool
}

@MainActor
final class MeetingAssistantService: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var transcript = "Waiting for speech…"
    @Published private(set) var translation = ""
    @Published private(set) var captionTimeline = CaptionTimeline()
    @Published private(set) var correctionSuggestion = ""
    @Published private(set) var contextTerms: [String] = []
    @Published private(set) var actionItems: [String] = []
    @Published private(set) var wordHints: [WordHint] = []
    @Published private(set) var meetingMode = MeetingLanguageSettings.mode
    @Published private(set) var statusMessage = "Ready"

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var insightTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var activeInsightID: UUID?
    private var pendingInsight: (text: String, isFinal: Bool)?
    private var activeTranslationID: UUID?
    private var activeTranslationJob: CaptionTimeline.Job?
    private var recentUtterances: [String] = []
    private var wordLookupTasks: [UUID: Task<Void, Never>] = [:]
    private var lastQueuedPartialUnits = 0

    func start() {
        guard !isRunning else { return }
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: MeetingLanguageSettings.source.speechLocale))
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            requestMicrophoneAccess()
        case .notDetermined:
            statusMessage = "Requesting Speech Recognition permission…"
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.handleSpeechAuthorization(status)
                }
            }
        case .denied, .restricted:
            statusMessage = "Enable Speech Recognition for ClipStash in System Settings."
            Self.openSpeechRecognitionPrivacySettings()
        @unknown default:
            statusMessage = "Speech Recognition permission is unavailable."
        }
    }

    func stop() {
        guard isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        insightTask?.cancel()
        translationTask?.cancel()
        captionTimeline.pause()
        activeInsightID = nil
        pendingInsight = nil
        activeTranslationID = nil
        activeTranslationJob = nil
        lastQueuedPartialUnits = 0
        recognitionRequest = nil
        recognitionTask = nil
        isRunning = false
        statusMessage = "Stopped"
    }

    func acceptCorrection() {
        guard !correctionSuggestion.isEmpty else { return }
        transcript = correctionSuggestion
        correctionSuggestion = ""
    }

    func setMeetingMode(_ mode: MeetingLanguageSettings.Mode) {
        meetingMode = mode
        MeetingLanguageSettings.save(mode: mode)
    }

    func lookUpWord(_ word: String, in sentence: String) {
        let cleanedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedWord.isEmpty else { return }

        // Keep each click as a separate entry so the dictionary area becomes a
        // newest-first lookup history instead of replacing the previous word.
        let hintID = UUID()
        wordHints.insert(WordHint(id: hintID, word: cleanedWord, detail: "", isLoading: true), at: 0)

        let useLocalModel = LocalModelManager.shared.useLocalModel
        let apiKey = AISettings.openAIAPIKey()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let hint = try await MeetingInferenceClient.wordHint(
                    for: cleanedWord,
                    targetLanguage: MeetingLanguageSettings.target.rawValue,
                    apiKey: apiKey,
                    useLocalModel: useLocalModel
                )
                guard !Task.isCancelled else { return }
                self.updateWordHint(id: hintID, detail: hint)
            } catch {
                guard !Task.isCancelled else { return }
                self.updateWordHint(id: hintID, detail: "Could not look up this word: \(error.localizedDescription)")
            }
            self.wordLookupTasks[hintID] = nil
        }
        wordLookupTasks[hintID] = task
    }

    func clearWordHints() {
        wordLookupTasks.values.forEach { $0.cancel() }
        wordLookupTasks.removeAll()
        wordHints.removeAll()
    }

    private func updateWordHint(id: UUID, detail: String) {
        guard let index = wordHints.firstIndex(where: { $0.id == id }) else { return }
        wordHints[index].detail = detail
        wordHints[index].isLoading = false
    }

    static func openMicrophonePrivacySettings() {
        openPrivacySettings(anchor: "Privacy_Microphone")
    }

    static func openSpeechRecognitionPrivacySettings() {
        openPrivacySettings(anchor: "Privacy_SpeechRecognition")
    }

    private func handleSpeechAuthorization(_ status: SFSpeechRecognizerAuthorizationStatus) {
        guard status == .authorized else {
            statusMessage = "Enable Speech Recognition for ClipStash in System Settings."
            Self.openSpeechRecognitionPrivacySettings()
            return
        }
        requestMicrophoneAccess()
    }

    private func requestMicrophoneAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startRecognition()
        case .notDetermined:
            statusMessage = "Requesting microphone permission…"
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] allowed in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if allowed {
                        self.startRecognition()
                    } else {
                        self.statusMessage = "Enable Microphone for ClipStash in System Settings."
                        Self.openMicrophonePrivacySettings()
                    }
                }
            }
        case .denied, .restricted:
            statusMessage = "Enable Microphone for ClipStash in System Settings."
            Self.openMicrophonePrivacySettings()
        @unknown default:
            statusMessage = "Microphone permission is unavailable."
        }
    }

    private static func openPrivacySettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func startRecognition() {
        guard let recognizer, recognizer.isAvailable else {
            statusMessage = "Speech recognition is unavailable for English."
            return
        }

        recognitionTask?.cancel()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.transcript = text
                    self.scheduleTranslation(for: text, isFinal: result.isFinal)
                    if result.isFinal {
                        self.scheduleInsight(for: text, isFinal: true)
                    }
                }
            }
            if let error {
                Task { @MainActor in
                    self.statusMessage = "Speech recognition stopped: \(error.localizedDescription)"
                    self.stop()
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRunning = true
            statusMessage = "Listening from microphone"
        } catch {
            inputNode.removeTap(onBus: 0)
            statusMessage = "Could not start microphone: \(error.localizedDescription)"
        }
    }

    private func scheduleInsight(for text: String, isFinal: Bool) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        guard meetingMode != .automatic else { return }

        guard LocalModelManager.shared.useLocalModel || AISettings.openAIAPIKey() != nil else {
            translation = "Add an OpenAI API key in ClipStash Settings to translate and extract action items."
            return
        }

        // Speech recognition updates partial captions several times per second. Keep the
        // request already on the wire so it can finish, then immediately translate only
        // the newest caption rather than cancelling every response before it arrives.
        guard activeInsightID == nil else {
            pendingInsight = (trimmedText, isFinal)
            statusMessage = "Updating translation…"
            return
        }

        startInsight(for: trimmedText, isFinal: isFinal)
    }

    // Fast path: partial speech results get a small, translation-only request.
    // A single in-flight stream is kept so continuous speech never overwhelms the model.
    private func scheduleTranslation(for text: String, isFinal: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let shouldQueue = shouldQueueTranslation(for: trimmed, isFinal: isFinal)
        captionTimeline.ingest(trimmed, isFinal: isFinal, queueTranslation: shouldQueue)
        guard LocalModelManager.shared.useLocalModel || AISettings.openAIAPIKey() != nil else {
            statusMessage = "Enable a local model or configure an API key in Settings."
            return
        }
        guard shouldQueue else { return }

        // A final speech result supersedes an in-flight short partial from the
        // same sentence. This avoids making the user wait for an obsolete
        // translation before the completed sentence can start.
        if isFinal,
           let active = activeTranslationJob,
           !active.isFinal,
           active.rowID == captionTimeline.rows.last?.id {
            cancelActiveTranslation()
        }
        guard activeTranslationID == nil, let job = captionTimeline.next() else { return }
        startTranslation(job)
    }

    /// The recognizer can revise text every few words. Translating each tiny
    /// revision makes a local model permanently trail the speaker. We submit
    /// immediately at a clause boundary, otherwise after a meaningful 6-word
    /// (or CJK-character) increment; final results always go through.
    private func shouldQueueTranslation(for text: String, isFinal: Bool) -> Bool {
        if isFinal {
            lastQueuedPartialUnits = 0
            return true
        }
        let whitespaceWords = text.split(whereSeparator: { $0.isWhitespace }).count
        let semanticUnits = max(whitespaceWords, text.count / 3)
        let endsClause = text.last.map { ".,;:!?。，“”！？；：".contains($0) } ?? false
        let hasMeaningfulIncrement = semanticUnits >= 6 && semanticUnits - lastQueuedPartialUnits >= 6
        guard endsClause || hasMeaningfulIncrement else { return false }
        lastQueuedPartialUnits = semanticUnits
        return true
    }

    private func cancelActiveTranslation() {
        activeTranslationID = nil
        activeTranslationJob = nil
        translationTask?.cancel()
        translationTask = nil
    }

    private func startTranslation(_ job: CaptionTimeline.Job) {
        let text = job.source
        let requestID = UUID()
        activeTranslationID = requestID
        activeTranslationJob = job
        let useLocalModel = LocalModelManager.shared.useLocalModel
        let apiKey = AISettings.openAIAPIKey()
        // Keep the previous Chinese line visible until the new stream yields its
        // first token; clearing here caused a noticeable flash on every partial caption.
        statusMessage = "Translating…"
        translationTask = Task { [weak self] in
            guard let self else { return }
            var latest = ""
            var lastDisplay = Date.distantPast
            do {
                try await MeetingInferenceClient.streamTranslation(for: text, targetLanguage: MeetingLanguageSettings.target.rawValue, apiKey: apiKey, useLocalModel: useLocalModel) { partial in
                    guard self.activeTranslationID == requestID else { return }
                    latest = partial
                    if Date().timeIntervalSince(lastDisplay) >= 0.1 {
                        self.captionTimeline.show(partial, for: job)
                        lastDisplay = Date()
                    }
                }
                guard self.activeTranslationID == requestID, !Task.isCancelled else { return }
                if latest.isEmpty {
                    self.captionTimeline.fail("No translation returned. Try again.", for: job)
                } else {
                    self.captionTimeline.show(latest, for: job, complete: true)
                }
            } catch {
                guard !Task.isCancelled, self.activeTranslationID == requestID else { return }
                self.statusMessage = "Translation failed: \(error.localizedDescription)"
                self.captionTimeline.fail(error.localizedDescription, for: job)
            }
            self.finishTranslation(requestID: requestID)
        }
    }

    private func finishTranslation(requestID: UUID) {
        guard activeTranslationID == requestID else { return }
        activeTranslationID = nil
        activeTranslationJob = nil
        translationTask = nil
        if let next = captionTimeline.next() {
            startTranslation(next)
        } else if isRunning {
            statusMessage = "Listening from microphone"
        }
    }

    private func startInsight(for text: String, isFinal: Bool) {
        let useLocalModel = LocalModelManager.shared.useLocalModel
        guard useLocalModel || AISettings.openAIAPIKey() != nil else { return }
        let apiKey = AISettings.openAIAPIKey()
        let requestID = UUID()
        activeInsightID = requestID

        insightTask = Task { [weak self] in
            guard !Task.isCancelled, let self else { return }
            self.statusMessage = "Translating…"
            do {
                let insight = try await MeetingInferenceClient.insight(for: text, context: self.recentUtterances.suffix(3).joined(separator: "\n"), glossary: MeetingGlossary.terms, targetLanguage: MeetingLanguageSettings.target.rawValue, mode: self.meetingMode, apiKey: apiKey, useLocalModel: useLocalModel)
                guard !Task.isCancelled else { return }
                // Do not replace the translation with one belonging to an older source
                // sentence. The queued latest caption starts immediately below.
                if self.transcript == text {
                    self.actionItems = insight.actionItems
                    self.contextTerms = insight.contextTerms
                    self.correctionSuggestion = insight.correction == text ? "" : insight.correction
                }
                if isFinal, self.recentUtterances.last != text {
                    self.recentUtterances.append(text)
                    recentUtterances = Array(recentUtterances.suffix(8))
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.statusMessage = "AI request failed: \(error.localizedDescription)"
            }
            self.finishInsight(requestID: requestID)
        }
    }

    private func finishInsight(requestID: UUID) {
        guard activeInsightID == requestID else { return }
        activeInsightID = nil
        insightTask = nil

        if let pendingInsight {
            self.pendingInsight = nil
            startInsight(for: pendingInsight.text, isFinal: pendingInsight.isFinal)
        } else if isRunning {
            statusMessage = "Listening from microphone"
        }
    }
}

private struct MeetingInsight {
    let translation: String
    let correction: String
    let contextTerms: [String]
    let actionItems: [String]
}

@MainActor
private enum MeetingInferenceClient {
    static func wordHint(for word: String, targetLanguage: String, apiKey: String?, useLocalModel: Bool) async throws -> String {
        let prompt = "Translate this single dictionary entry into concise \(targetLanguage): \(word). Return only the translation. Do not explain it, add context, labels, punctuation, or extra words."
        if useLocalModel {
            let base = try await LocalModelManager.shared.serverURL()
            var request = URLRequest(url: base.appendingPathComponent("v1/chat/completions"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "messages": [["role": "user", "content": prompt]],
                "temperature": 0.1,
                "max_tokens": 80,
                "chat_template_kwargs": ["enable_thinking": false]
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            let payload = try JSONDecoder().decode(LocalPayload.self, from: data)
            return payload.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No explanation returned."
        }
        guard let apiKey else { throw URLError(.userAuthenticationRequired) }
        return try await OpenAIMeetingClient.plainText(prompt: prompt, apiKey: apiKey)
    }

    static func streamTranslation(for transcript: String, targetLanguage: String, apiKey: String?, useLocalModel: Bool, onDelta: @escaping (String) -> Void) async throws {
        if useLocalModel {
            let base = try await LocalModelManager.shared.serverURL()
            var request = URLRequest(url: base.appendingPathComponent("v1/chat/completions"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "messages": [["role": "user", "content": "Translate the following meeting caption into concise \(targetLanguage). Return only the translation, with no notes or labels. Caption: \(transcript)"]],
                "temperature": 0.1,
                "max_tokens": 64,
                "stream": true,
                // Qwen3 otherwise spends the small fast-path budget emitting
                // reasoning_content before translation tokens.
                "chat_template_kwargs": ["enable_thinking": false]
            ])
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            var result = ""
            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let value = String(line.dropFirst(6))
                if value == "[DONE]" { break }
                guard let data = value.data(using: .utf8),
                      let event = try? JSONDecoder().decode(LocalStreamEvent.self, from: data),
                      let delta = event.choices.first?.delta.content else { continue }
                result += delta
                onDelta(result)
            }
            return
        }
        guard let apiKey else { throw URLError(.userAuthenticationRequired) }
        let insight = try await OpenAIMeetingClient.insight(for: transcript, context: "", glossary: [], targetLanguage: targetLanguage, mode: .automatic, apiKey: apiKey)
        onDelta(insight.translation)
    }

    static func insight(for transcript: String, context: String, glossary: [String], targetLanguage: String, mode: MeetingLanguageSettings.Mode, apiKey: String?, useLocalModel: Bool) async throws -> MeetingInsight {
        if useLocalModel {
            let base = try await LocalModelManager.shared.serverURL()
            var request = URLRequest(url: base.appendingPathComponent("v1/chat/completions")); request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let modeInstruction = mode == .meeting ? "For action_items, list only explicit commitments or decisions." : "For action_items, list only concise video takeaways. For context_terms, include concepts worth explaining."
            let prompt = "Return JSON only with translation, correction, context_terms, action_items. Translate this caption to concise \(targetLanguage). \(modeInstruction) Context: \(context). Glossary: \(glossary.joined(separator: ", ")). Caption: \(transcript)"
            request.httpBody = try JSONSerialization.data(withJSONObject: ["messages": [["role": "user", "content": prompt]], "temperature": 0.1, "max_tokens": 300])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            let payload = try JSONDecoder().decode(LocalPayload.self, from: data)
            let output = payload.choices.first?.message.content ?? "{}"
            return try decode(output, fallback: transcript)
        }
        return try await OpenAIMeetingClient.insight(for: transcript, context: context, glossary: glossary, targetLanguage: targetLanguage, mode: mode, apiKey: apiKey!)
    }
    private static func decode(_ text: String, fallback: String) throws -> MeetingInsight {
        let json = text.firstIndex(of: "{").flatMap { start in text.lastIndex(of: "}").map { String(text[start...$0]) } } ?? text
        let value = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        return MeetingInsight(translation: value?["translation"] as? String ?? fallback, correction: value?["correction"] as? String ?? fallback, contextTerms: value?["context_terms"] as? [String] ?? [], actionItems: value?["action_items"] as? [String] ?? [])
    }
    private struct LocalPayload: Decodable { struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }; let choices: [Choice] }
    private struct LocalStreamEvent: Decodable { struct Choice: Decodable { struct Delta: Decodable { let content: String? }; let delta: Delta }; let choices: [Choice] }
}

private enum OpenAIMeetingClient {
    static func plainText(prompt: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-5-mini",
            "store": false,
            "input": prompt
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError(message: String(data: data, encoding: .utf8) ?? "Server error")
        }
        let payload = try JSONDecoder().decode(ResponsePayload.self, from: data)
        let output = payload.output.compactMap(\.content).flatMap { $0 }.compactMap(\.text).joined(separator: "\n")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func insight(for transcript: String, context: String, glossary: [String], targetLanguage: String, mode: MeetingLanguageSettings.Mode, apiKey: String) async throws -> MeetingInsight {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "translation": ["type": "string"],
                "correction": ["type": "string"],
                "context_terms": ["type": "array", "items": ["type": "string"]],
                "action_items": ["type": "array", "items": ["type": "string"]]
            ],
            "required": ["translation", "correction", "context_terms", "action_items"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-5-mini",
            "store": false,
            "text": ["format": [
                "type": "json_schema",
                "name": "meeting_caption_insight",
                "strict": true,
                "schema": schema
            ]],
            "input": """
            Translate the current caption into concise \(targetLanguage). Use the glossary and recent context only to improve spelling of proper nouns and technical terms. Never invent facts. Return the original caption as correction when no correction is needed. \(mode == .meeting ? "Only list explicit commitments or decisions as action items." : "Use action items for concise video takeaways and context terms for concepts worth explaining.")

            Glossary: \(glossary.joined(separator: ", "))
            Recent context: \(context)
            Current caption: \(transcript)
            """
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw APIError(message: message)
        }

        let payload = try JSONDecoder().decode(ResponsePayload.self, from: data)
        let output = payload.output
            .compactMap(\.content)
            .flatMap { $0 }
            .compactMap(\.text)
            .joined(separator: "\n")
        let insight = try JSONDecoder().decode(InsightPayload.self, from: Data(output.utf8))
        return MeetingInsight(
            translation: insight.translation,
            correction: insight.correction,
            contextTerms: insight.contextTerms,
            actionItems: insight.actionItems
        )
    }

    private struct ResponsePayload: Decodable {
        let output: [Output]

        struct Output: Decodable {
            let content: [Content]?
        }

        struct Content: Decodable {
            let type: String
            let text: String?
        }
    }

    private struct InsightPayload: Decodable {
        let translation: String
        let correction: String
        let contextTerms: [String]
        let actionItems: [String]

        enum CodingKeys: String, CodingKey {
            case translation, correction
            case contextTerms = "context_terms"
            case actionItems = "action_items"
        }
    }

    private struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}

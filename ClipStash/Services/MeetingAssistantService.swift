import AppKit
import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class MeetingAssistantService: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var transcript = "Waiting for speech…"
    @Published private(set) var translation = ""
    @Published private(set) var correctionSuggestion = ""
    @Published private(set) var contextTerms: [String] = []
    @Published private(set) var actionItems: [String] = []
    @Published private(set) var statusMessage = "Ready"

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var insightTask: Task<Void, Never>?
    private var activeInsightID: UUID?
    private var pendingInsight: (text: String, isFinal: Bool)?
    private var recentUtterances: [String] = []

    func start() {
        guard !isRunning else { return }
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
        activeInsightID = nil
        pendingInsight = nil
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
                    self.scheduleInsight(for: text, isFinal: result.isFinal)
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
                let insight = try await MeetingInferenceClient.insight(for: text, context: self.recentUtterances.suffix(3).joined(separator: "\n"), glossary: MeetingGlossary.terms, apiKey: apiKey, useLocalModel: useLocalModel)
                guard !Task.isCancelled else { return }
                // Do not replace the translation with one belonging to an older source
                // sentence. The queued latest caption starts immediately below.
                if self.transcript == text {
                    self.translation = insight.translation
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

private enum MeetingInferenceClient {
    static func insight(for transcript: String, context: String, glossary: [String], apiKey: String?, useLocalModel: Bool) async throws -> MeetingInsight {
        if useLocalModel {
            let base = try await LocalModelManager.shared.serverURL()
            var request = URLRequest(url: base.appendingPathComponent("v1/chat/completions")); request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let prompt = "Return JSON only with translation, correction, context_terms, action_items. Translate this meeting caption to concise Simplified Chinese. Context: \(context). Glossary: \(glossary.joined(separator: ", ")). Caption: \(transcript)"
            request.httpBody = try JSONSerialization.data(withJSONObject: ["messages": [["role": "user", "content": prompt]], "temperature": 0.1, "max_tokens": 300])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            let payload = try JSONDecoder().decode(LocalPayload.self, from: data)
            let output = payload.choices.first?.message.content ?? "{}"
            return try decode(output, fallback: transcript)
        }
        return try await OpenAIMeetingClient.insight(for: transcript, context: context, glossary: glossary, apiKey: apiKey!)
    }
    private static func decode(_ text: String, fallback: String) throws -> MeetingInsight {
        let json = text.firstIndex(of: "{").flatMap { start in text.lastIndex(of: "}").map { String(text[start...$0]) } } ?? text
        let value = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        return MeetingInsight(translation: value?["translation"] as? String ?? fallback, correction: value?["correction"] as? String ?? fallback, contextTerms: value?["context_terms"] as? [String] ?? [], actionItems: value?["action_items"] as? [String] ?? [])
    }
    private struct LocalPayload: Decodable { struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }; let choices: [Choice] }
}

private enum OpenAIMeetingClient {
    static func insight(for transcript: String, context: String, glossary: [String], apiKey: String) async throws -> MeetingInsight {
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
            Translate the current meeting caption into concise Simplified Chinese. Use the glossary and recent context only to improve spelling of proper nouns and technical terms. Never invent facts. Return the original caption as correction when no correction is needed. Only list explicit commitments as action items.

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

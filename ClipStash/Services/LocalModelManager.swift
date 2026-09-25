import Foundation
import Combine

@MainActor
final class LocalModelManager: ObservableObject {
    static let shared = LocalModelManager()
    enum State: Equatable { case notDownloaded, downloading(Double), ready, failed(String) }
    enum Model: String, CaseIterable, Identifiable {
        case qwen3_4b, gemma3_4b

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .qwen3_4b: return "Qwen3 4B (Q4_K_M)"
            case .gemma3_4b: return "Gemma 3 4B IT (Q4_0)"
            }
        }
        var fileName: String {
            switch self {
            case .qwen3_4b: return "Qwen3-4B-Q4_K_M.gguf"
            case .gemma3_4b: return "gemma-3-4b-it-q4_0.gguf"
            }
        }
        var downloadURL: URL {
            switch self {
            case .qwen3_4b:
                return URL(string: "https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf?download=true")!
            case .gemma3_4b:
                return URL(string: "https://huggingface.co/google/gemma-3-4b-it-qat-q4_0-gguf/resolve/main/gemma-3-4b-it-q4_0.gguf?download=true")!
            }
        }
        var requiresHuggingFaceToken: Bool { self == .gemma3_4b }
        var accessPage: URL? {
            requiresHuggingFaceToken ? URL(string: "https://huggingface.co/google/gemma-3-4b-it-qat-q4_0-gguf") : nil
        }
        var port: Int { self == .qwen3_4b ? 11436 : 11437 }
    }

    @Published private(set) var state: State
    @Published private(set) var selectedModel: Model
    @Published var useLocalModel: Bool {
        didSet {
            UserDefaults.standard.set(useLocalModel, forKey: "useLocalMeetingModel")
            if useLocalModel { warmUpSelectedModelIfNeeded() }
        }
    }
    private var downloadTask: URLSessionDownloadTask?
    private var observation: NSKeyValueObservation?
    private var server: Process?
    private var serverModel: Model?

    private init() {
        let initialModel = Model(rawValue: UserDefaults.standard.string(forKey: "selectedLocalMeetingModel") ?? "") ?? .qwen3_4b
        selectedModel = initialModel
        useLocalModel = UserDefaults.standard.bool(forKey: "useLocalMeetingModel")
        state = FileManager.default.fileExists(atPath: Self.modelsDirectory.appendingPathComponent(initialModel.fileName).path) ? .ready : .notDownloaded
    }
    static var modelsDirectory: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClipStash/Models", isDirectory: true) }
    var modelURL: URL { Self.modelsDirectory.appendingPathComponent(selectedModel.fileName) }
    var statusText: String {
        switch state { case .notDownloaded: return "Not downloaded"; case .downloading(let p): return "Downloading \(Int(p * 100))%"; case .ready: return "Ready for offline use"; case .failed(let error): return error }
    }
    func select(_ model: Model) {
        guard model != selectedModel else { return }
        downloadTask?.cancel()
        observation?.invalidate()
        server?.terminate()
        server = nil
        serverModel = nil
        selectedModel = model
        UserDefaults.standard.set(model.rawValue, forKey: "selectedLocalMeetingModel")
        state = FileManager.default.fileExists(atPath: modelURL.path) ? .ready : .notDownloaded
        useLocalModel = state == .ready
    }

    /// Gemma has a noticeable first-load cost. Start it as soon as the user
    /// selects the downloaded model, so a meeting does not pay that cost on its
    /// first spoken sentence. Qwen keeps its original on-demand behavior.
    func warmUpSelectedModelIfNeeded() {
        guard useLocalModel, selectedModel == .gemma3_4b, state == .ready, server == nil else { return }
        Task { [weak self] in
            guard let self else { return }
            _ = try? await self.serverURL()
        }
    }

    func downloadSelectedModel() {
        guard case .downloading = state else {
            if selectedModel.requiresHuggingFaceToken, AISettings.huggingFaceAccessToken() == nil {
                state = .failed("Gemma requires a Hugging Face read token after accepting Google's license.")
                return
            }
            do {
                try FileManager.default.createDirectory(at: Self.modelsDirectory, withIntermediateDirectories: true)
                var request = URLRequest(url: selectedModel.downloadURL)
                if let token = AISettings.huggingFaceAccessToken(), selectedModel.requiresHuggingFaceToken {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                let model = selectedModel
                let task = URLSession.shared.downloadTask(with: request) { [weak self] temporaryURL, response, error in
                    DispatchQueue.main.async {
                        guard let self else { return }; self.observation?.invalidate(); self.observation = nil; self.downloadTask = nil
                        if let error { self.state = .failed("Download failed: \(error.localizedDescription)"); return }
                        if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                            self.state = .failed(model.requiresHuggingFaceToken ? "Gemma access was denied. Accept the license and check the Hugging Face token." : "Download failed (HTTP \(response.statusCode)).")
                            return
                        }
                        guard let temporaryURL else { self.state = .failed("Download did not return a model file."); return }
                        guard self.selectedModel == model else { return }
                        do { let fm = FileManager.default; if fm.fileExists(atPath: self.modelURL.path) { try fm.removeItem(at: self.modelURL) }; try fm.moveItem(at: temporaryURL, to: self.modelURL); self.state = .ready } catch { self.state = .failed("Could not save model: \(error.localizedDescription)") }
                    }
                }
                observation = task.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] progress, _ in DispatchQueue.main.async { self?.state = .downloading(progress.fractionCompleted) } }
                downloadTask = task; task.resume()
            } catch { state = .failed("Could not create model folder: \(error.localizedDescription)") }
            return
        }
    }
    func removeDefaultModel() {
        downloadTask?.cancel(); observation?.invalidate(); observation = nil; downloadTask = nil
        shutdownServer()
        do { if FileManager.default.fileExists(atPath: modelURL.path) { try FileManager.default.removeItem(at: modelURL) }; useLocalModel = false; state = .notDownloaded } catch { state = .failed("Could not remove model: \(error.localizedDescription)") }
    }

    func shutdownServer() {
        server?.terminate()
        server = nil
        serverModel = nil
    }

    func serverURL() async throws -> URL {
        let model = selectedModel
        let baseURL = URL(string: "http://127.0.0.1:\(model.port)")!
        if serverModel == model, await isHealthy(baseURL) { return baseURL }
        guard state == .ready, let executable = Bundle.main.resourceURL?.appendingPathComponent("LocalInference/llama-server") else { throw LocalError.runtimeUnavailable }
        let process = Process(); process.executableURL = executable
        var arguments = ["--model", modelURL.path, "--host", "127.0.0.1", "--port", "\(model.port)", "--ctx-size", model == .gemma3_4b ? "2048" : "4096", "--no-webui"]
        if model == .gemma3_4b {
            // Keep Gemma's 4B Q4 model resident on Apple Silicon's Metal GPU.
            // Qwen deliberately retains its existing automatic configuration.
            arguments += ["--device", "MTL0", "--gpu-layers", "all", "--flash-attn", "on"]
        }
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["DYLD_LIBRARY_PATH": executable.deletingLastPathComponent().path]) { _, new in new }
        try process.run(); server = process; serverModel = model
        for _ in 0..<300 {
            try await Task.sleep(for: .milliseconds(100))
            if await isHealthy(baseURL) { return baseURL }
            if !process.isRunning { break }
        }
        throw LocalError.serverDidNotStart
    }
    private func isHealthy(_ baseURL: URL) async -> Bool {
        do {
            let (_, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("health"))
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }
    enum LocalError: LocalizedError { case runtimeUnavailable, serverDidNotStart; var errorDescription: String? { self == .runtimeUnavailable ? "Local inference runtime or model is unavailable." : "Local model server did not start." } }
}

import Foundation
import Combine

@MainActor
final class LocalModelManager: ObservableObject {
    static let shared = LocalModelManager()
    enum State: Equatable { case notDownloaded, downloading(Double), ready, failed(String) }
    static let modelFileName = "Qwen3-4B-Q4_K_M.gguf"
    static let modelDownloadURL = URL(string: "https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf?download=true")!
    @Published private(set) var state: State
    @Published var useLocalModel: Bool { didSet { UserDefaults.standard.set(useLocalModel, forKey: "useLocalMeetingModel") } }
    private var downloadTask: URLSessionDownloadTask?
    private var observation: NSKeyValueObservation?
    private var server: Process?
    private let serverPort = 11436

    private init() {
        useLocalModel = UserDefaults.standard.bool(forKey: "useLocalMeetingModel")
        state = FileManager.default.fileExists(atPath: Self.modelURL.path) ? .ready : .notDownloaded
    }
    static var modelsDirectory: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClipStash/Models", isDirectory: true) }
    static var modelURL: URL { modelsDirectory.appendingPathComponent(modelFileName) }
    var statusText: String {
        switch state { case .notDownloaded: return "Not downloaded"; case .downloading(let p): return "Downloading \(Int(p * 100))%"; case .ready: return "Ready for offline use"; case .failed(let error): return error }
    }
    func downloadDefaultModel() {
        guard case .downloading = state else {
            do {
                try FileManager.default.createDirectory(at: Self.modelsDirectory, withIntermediateDirectories: true)
                let task = URLSession.shared.downloadTask(with: Self.modelDownloadURL) { [weak self] temporaryURL, _, error in
                    DispatchQueue.main.async {
                        guard let self else { return }; self.observation?.invalidate(); self.observation = nil; self.downloadTask = nil
                        if let error { self.state = .failed("Download failed: \(error.localizedDescription)"); return }
                        guard let temporaryURL else { self.state = .failed("Download did not return a model file."); return }
                        do { let fm = FileManager.default; if fm.fileExists(atPath: Self.modelURL.path) { try fm.removeItem(at: Self.modelURL) }; try fm.moveItem(at: temporaryURL, to: Self.modelURL); self.state = .ready } catch { self.state = .failed("Could not save model: \(error.localizedDescription)") }
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
        do { if FileManager.default.fileExists(atPath: Self.modelURL.path) { try FileManager.default.removeItem(at: Self.modelURL) }; useLocalModel = false; state = .notDownloaded } catch { state = .failed("Could not remove model: \(error.localizedDescription)") }
    }

    func serverURL() async throws -> URL {
        let baseURL = URL(string: "http://127.0.0.1:\(serverPort)")!
        if await isHealthy(baseURL) { return baseURL }
        guard state == .ready, let executable = Bundle.main.resourceURL?.appendingPathComponent("LocalInference/llama-server") else { throw LocalError.runtimeUnavailable }
        let process = Process(); process.executableURL = executable
        process.arguments = ["--model", Self.modelURL.path, "--host", "127.0.0.1", "--port", "\(serverPort)", "--ctx-size", "4096", "--no-webui"]
        process.environment = ProcessInfo.processInfo.environment.merging(["DYLD_LIBRARY_PATH": executable.deletingLastPathComponent().path]) { _, new in new }
        try process.run(); server = process
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

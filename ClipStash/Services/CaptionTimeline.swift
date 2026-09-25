import Foundation

/// A translation always belongs to an immutable source snapshot and a stable row.
struct CaptionTimeline {
    struct Job: Equatable {
        let rowID: UUID
        let source: String
        let isFinal: Bool
    }
    struct Row: Identifiable {
        let id: UUID
        var source: String
        var translation = ""
        var translatedSource = ""
        var preview = ""
        var isFinal = false
        var error: String?
        var displayedSource: String { translatedSource.isEmpty ? source : translatedSource }
    }
    private(set) var rows: [Row] = []
    private(set) var pending: [Job] = []
    private var currentID: UUID?

    /// Updates the visible source immediately. The caller decides when a
    /// partial result is substantial enough to become an inference job.
    mutating func ingest(_ text: String, isFinal: Bool, queueTranslation: Bool = true) {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        if currentID == nil {
            currentID = UUID()
            rows.append(Row(id: currentID!, source: source))
        }
        let id = currentID!
        if let index = rows.firstIndex(where: { $0.id == id }) {
            rows[index].source = source
            rows[index].isFinal = isFinal
        }
        if queueTranslation {
            let job = Job(rowID: id, source: source, isFinal: isFinal)
            // There is at most one waiting job per spoken sentence: when the
            // recognizer revises its partial text, the model receives only the
            // newest version rather than translating stale fragments in order.
            if let index = pending.firstIndex(where: { $0.rowID == id }) {
                pending[index] = job
            } else { pending.append(job) }
        }
        if isFinal { currentID = nil }
    }

    mutating func next() -> Job? { pending.isEmpty ? nil : pending.removeFirst() }

    mutating func show(_ text: String, for job: Job, complete: Bool = false) {
        guard !text.isEmpty, let i = rows.firstIndex(where: { $0.id == job.rowID }) else { return }
        // Revisions are buffered until complete; an existing sentence never shrinks
        // to the first token of a newly generated translation.
        if complete {
            rows[i].translation = text
            rows[i].translatedSource = job.source
            rows[i].preview = ""
        } else if rows[i].translation.isEmpty {
            rows[i].translatedSource = job.source
            rows[i].preview = text
        }
        rows[i].error = nil
    }

    mutating func fail(_ message: String, for job: Job) {
        guard let i = rows.firstIndex(where: { $0.id == job.rowID }) else { return }
        rows[i].error = message
    }

    mutating func pause() {
        pending.removeAll()
        currentID = nil
        for i in rows.indices where !rows[i].isFinal {
            rows[i].isFinal = true
        }
    }
}

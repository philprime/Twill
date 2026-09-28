@testable import Twill

@MainActor
final class RecordingTerminalViewport: TerminalViewport {
    private var dimensions: TerminalSize?
    private var pendingResult: Result<TerminalSize, any Error>?
    private var registration: RunLoopSourceRegistration?
    private(set) var isStarted = false
    private(set) var isStopped = false

    init(columns: Int? = nil, rows: Int? = nil) {
        if let columns, let rows { dimensions = TerminalSize(columns: columns, rows: rows) }
    }

    func start(signaling registration: RunLoopSourceRegistration) throws -> TerminalSize? {
        isStarted = true
        self.registration = registration
        return dimensions
    }

    func consume() throws -> TerminalSize? {
        guard let result = pendingResult else { return nil }
        pendingResult = nil
        return try result.get()
    }

    func cancel() {
        registration = nil
        pendingResult = nil
    }

    func stop() async {
        cancel()
        isStopped = true
    }

    func resize(columns: Int, rows: Int) {
        let size = TerminalSize(columns: columns, rows: rows)
        dimensions = size
        pendingResult = .success(size)
        registration?.signal()
    }

    func fail(_ error: Error) {
        pendingResult = .failure(error)
        registration?.signal()
    }
}

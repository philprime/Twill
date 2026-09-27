@testable import Twill

@MainActor
final class RecordingTerminalViewport: TerminalViewport {
    let events: AsyncThrowingStream<TerminalSize, Error>
    private let continuation: AsyncThrowingStream<TerminalSize, Error>.Continuation
    private var dimensions: TerminalSize?
    private(set) var isStarted = false
    private(set) var isStopped = false

    init(columns: Int? = nil, rows: Int? = nil) {
        if let columns, let rows { dimensions = TerminalSize(columns: columns, rows: rows) }
        (events, continuation) = AsyncThrowingStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    func start() throws -> TerminalSize? {
        isStarted = true
        return dimensions
    }

    func cancel() { continuation.finish() }
    func stop() async {
        cancel()
        isStopped = true
    }

    func resize(columns: Int, rows: Int) {
        let size = TerminalSize(columns: columns, rows: rows)
        dimensions = size
        continuation.yield(size)
    }

    func fail(_ error: Error) { continuation.finish(throwing: error) }
}

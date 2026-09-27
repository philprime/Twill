import Twill

/// Makes asynchronous cleanup observable without relying on worker-queue timing.
@MainActor
final class GatedInputSource: InputSource {
    let events: AsyncThrowingStream<[UInt8], Error>
    let cleanupStarted: AsyncStream<Void>
    var onCancelDuringCleanup: (() -> Void)?
    private let eventsContinuation: AsyncThrowingStream<[UInt8], Error>.Continuation
    private let cleanupContinuation: AsyncStream<Void>.Continuation
    private var cleanupCompletion: CheckedContinuation<Void, Never>?
    private let failure: TerminalError?
    private let finishesAfterBytes: Bool

    init(failure: TerminalError? = nil, finishesAfterBytes: Bool = false) {
        self.failure = failure
        self.finishesAfterBytes = finishesAfterBytes
        (events, eventsContinuation) = AsyncThrowingStream.makeStream()
        (cleanupStarted, cleanupContinuation) = AsyncStream.makeStream()
    }

    func start() {
        if let failure {
            eventsContinuation.finish(throwing: failure)
        } else {
            eventsContinuation.yield([0x61])
            if finishesAfterBytes { eventsContinuation.finish() }
        }
    }

    func cancel() {
        eventsContinuation.finish()
        if cleanupCompletion != nil { onCancelDuringCleanup?() }
    }

    func stop() async {
        cancel()
        await withCheckedContinuation { completion in
            cleanupCompletion = completion
            cleanupContinuation.yield(())
            cleanupContinuation.finish()
        }
    }

    func allowCleanup() {
        cleanupCompletion?.resume()
        cleanupCompletion = nil
    }
}

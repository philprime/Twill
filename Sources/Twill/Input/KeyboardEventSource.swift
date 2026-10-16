import Dispatch

#if TESTING
    /// A replaceable source that decodes terminal bytes into keys on the UI actor.
    @MainActor
    public protocol KeyboardEventSource: AnyObject, Sendable {
        /// The synchronous handler for each decoded key.
        var onKeyEvent: (@MainActor (KeyEvent) -> Void)? { get set }
        /// Delivers keys until input ends, shutdown is requested, or the task is cancelled; awaits reader cleanup.
        func run() async throws
        /// Requests shutdown and wakes an idle input consumer.
        func stop()
    }

    extension DefaultKeyboardEventSource: KeyboardEventSource {}
#else
    /// The concrete terminal key decoder used by an application.
    public typealias KeyboardEventSource = DefaultKeyboardEventSource
#endif

/// Decodes a single input stream on the UI actor without another queue or task hop.
///
/// The application owns the task running this source. Key handlers execute synchronously
/// on the same actor, so stopping inside a handler suppresses the rest of that byte batch.
/// Keyboard interpretation belongs here; application shortcuts such as Ctrl-C do not.
@MainActor
public final class DefaultKeyboardEventSource {
    private static let escapeTimeout: DispatchTimeInterval = .milliseconds(50)

    /// The synchronous UI-actor handler invoked for each decoded key.
    public var onKeyEvent: (@MainActor (KeyEvent) -> Void)?
    private let inputSource: InputSource
    private let runLoop: RunLoop
    private var parser = InputParser()
    private var escapeGeneration = 0
    private var isStopped = false

    /// Creates a decoder using the supplied byte source and run loop for Escape disambiguation.
    public init(inputSource: InputSource, runLoop: RunLoop) {
        self.inputSource = inputSource
        self.runLoop = runLoop
    }

    /// Single-use. Returns after EOF, stop, or cancellation and awaited reader cleanup.
    public func run() async throws {
        guard !isStopped, !Task.isCancelled else { return }
        inputSource.start()
        do {
            for try await bytes in inputSource.events {
                guard !isStopped, !Task.isCancelled else { break }
                handle(bytes)
                if isStopped { break }
            }
        } catch {
            stop()
            await inputSource.stop()
            throw error
        }
        stop()
        await inputSource.stop()
    }

    /// Requests shutdown immediately; run() awaits cleanup before returning.
    public func stop() {
        isStopped = true
        // Finishing the byte stream wakes an idle consumer. This is a cancellation
        // request only, not asynchronous cleanup hidden in an unstructured task.
        inputSource.cancel()
    }

    private func handle(_ bytes: [UInt8]) {
        // Escape is both a key and a sequence prefix. A later chunk supersedes the
        // old deadline, which must not flush a newer partially received sequence.
        escapeGeneration += 1
        for key in parser.parse(bytes) {
            guard !isStopped else { break }
            onKeyEvent?(key)
        }
        guard !isStopped, parser.needsEscapeDeadline else { return }
        let generation = escapeGeneration
        runLoop.add(
            Timer(interval: Self.escapeTimeout) { [weak self] in
                guard let self, !isStopped, escapeGeneration == generation else { return }
                for key in parser.expireEscape() {
                    onKeyEvent?(key)
                }
            })
    }
}

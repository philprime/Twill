import Dispatch

/// Owns the serialized TUI application lifecycle.
@MainActor
public final class Application {
    private static let escapeTimeout: DispatchTimeInterval = .milliseconds(50)
    private static let interruptKey = KeyEvent.control(0x03)

    private let runLoop: RunLoop
    private let terminalSession: TerminalSession
    private var parser = InputParser()
    private var escapeGeneration = 0
    private var inputError: TerminalError?
    private var isStopping = false

    public init(runLoop: RunLoop = DefaultRunLoop(), terminalSession: TerminalSession = DefaultTerminalSession()) {
        self.runLoop = runLoop
        self.terminalSession = terminalSession
    }

    /// Set before run() to enable keyboard input. Replacing or clearing this handler
    /// while running affects the next event, including events in the same input batch.
    public var onKeyEvent: (@MainActor (KeyEvent) -> Void)?

    public func stop() {
        isStopping = true
        runLoop.stop()
    }

    /// Runs until stopped or cancelled. Without a key handler, terminal modes are untouched.
    /// With keyboard input enabled, Ctrl-C requests an orderly shutdown in raw mode.
    public func run() async throws {
        guard onKeyEvent != nil else {
            await runLoop.run()
            return
        }
        // The run loop cancels readers before returning, so restoring terminal mode
        // cannot race with a worker that is still draining the descriptor.
        try terminalSession.start()
        defer { terminalSession.restore() }
        let input = DefaultInputSource(fileDescriptor: terminalSession.fileDescriptor) { [weak self] event in
            guard let self else { return }
            switch event {
            case .bytes(let bytes):
                handle(bytes)
            case .endOfFile:
                stop()
            case .failure(let error):
                inputError = error
                stop()
            }
        }
        runLoop.add(input)
        await runLoop.run()
        if let inputError { throw inputError }
    }

    private func handle(_ bytes: [UInt8]) {
        // Escape is both a key and a sequence prefix. A later chunk supersedes the
        // old deadline, which must not flush a newer partially received sequence.
        escapeGeneration += 1
        for key in parser.parse(bytes) {
            guard !isStopping else { break }
            if key == Self.interruptKey {
                stop()
            } else {
                onKeyEvent?(key)
            }
        }
        guard !isStopping, parser.needsEscapeDeadline else { return }
        let generation = escapeGeneration
        runLoop.add(
            Timer(interval: Self.escapeTimeout) { [weak self] in
                guard let self, !isStopping, escapeGeneration == generation else { return }
                for key in parser.expireEscape() {
                    onKeyEvent?(key)
                }
            })
    }
}

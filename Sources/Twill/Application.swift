/// Owns the serialized TUI application lifecycle and application-level key policy.
@MainActor
public final class Application {
    private static let interruptKey = KeyEvent.control(0x03)

    private let runLoop: RunLoop
    private let terminalSession: TerminalSession
    private let keyboardEventSource: KeyboardEventSource
    private var isStopping = false

    public init(
        runLoop: RunLoop = DefaultRunLoop(),
        terminalSession: TerminalSession = DefaultTerminalSession(),
        keyboardEventSource: KeyboardEventSource? = nil
    ) {
        self.runLoop = runLoop
        self.terminalSession = terminalSession
        self.keyboardEventSource =
            keyboardEventSource
            ?? DefaultKeyboardEventSource(
                inputSource: DefaultInputSource(fileDescriptor: terminalSession.fileDescriptor),
                runLoop: runLoop
            )
    }

    /// May be installed, replaced, or cleared while running. Keyboard input and
    /// orderly Ctrl-C shutdown remain active even when no handler is installed.
    public var onKeyEvent: (@MainActor (KeyEvent) -> Void)?

    public func stop() {
        isStopping = true
        keyboardEventSource.stop()
        runLoop.stop()
    }

    /// Owns the terminal until stopped or cancelled. Ctrl-C requests orderly shutdown
    /// regardless of whether an application key handler is installed.
    public func run() async throws {
        guard !isStopping, !Task.isCancelled else {
            stop()
            return
        }
        try terminalSession.start()
        keyboardEventSource.onKeyEvent = { [weak self] key in self?.handle(key) }
        defer {
            keyboardEventSource.onKeyEvent = nil
            terminalSession.restore()
        }

        // One long-lived task consumes bytes directly on the UI actor, while another
        // awaits timers. There is no forwarding task, second input queue, or per-key task.
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { stop() }
            group.addTask { @MainActor @Sendable [self] in
                try await keyboardEventSource.run()
            }
            group.addTask { @MainActor @Sendable [self] in
                await runLoop.run()
            }
            // Observe both results: timer shutdown must not hide an input failure
            // still awaiting cleanup. Structured scope joins both tasks before restore.
            for try await _ in group {
                stop()
                group.cancelAll()
            }
        }
    }

    private func handle(_ key: KeyEvent) {
        guard !isStopping else { return }
        if key == Self.interruptKey {
            stop()
        } else {
            onKeyEvent?(key)
        }
    }
}

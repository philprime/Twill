/// Owns the serialized TUI application lifecycle and application-level key policy.
@MainActor
public final class Application {
    private static let interruptKey = KeyEvent.control(0x03)

    public let options: ApplicationOptions

    private let runLoop: RunLoop
    private let terminalSession: TerminalSession
    private let keyboardEventSource: KeyboardEventSource
    private let viewHost: ViewHost
    private let terminalViewport: TerminalViewport
    private var renderingError: Error?
    private var isStopping = false

    public init(
        rootView: any View,
        runLoop: RunLoop = DefaultRunLoop(),
        terminalSession: TerminalSession = DefaultTerminalSession(),
        keyboardEventSource: KeyboardEventSource? = nil,
        terminalViewport: TerminalViewport = DefaultTerminalViewport()
    ) {
        let options = ApplicationOptions()
        self.options = options
        self.runLoop = runLoop
        self.terminalSession = terminalSession
        self.keyboardEventSource =
            keyboardEventSource
            ?? DefaultKeyboardEventSource(
                inputSource: DefaultInputSource(fileDescriptor: terminalSession.fileDescriptor),
                runLoop: runLoop
            )
        self.terminalViewport = terminalViewport
        viewHost = ViewHost(
            rootView: rootView, runLoop: runLoop, output: terminalSession.output,
            preparePresentation: { try terminalSession.beginPresentation(mode: options.ui.mode) }
        )
    }

    /// May be installed, replaced, or cleared while running. Keyboard input and
    /// orderly Ctrl-C shutdown remain active even when no handler is installed.
    public var onKeyEvent: (@MainActor (KeyEvent) -> Void)?

    public func stop() {
        isStopping = true
        keyboardEventSource.stop()
        terminalViewport.cancel()
        viewHost.stop()
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
        viewHost.onError = { [weak self] error in self?.presentationFailed(error) }
        defer {
            stop()
            viewHost.onError = nil
            keyboardEventSource.onKeyEvent = nil
            terminalSession.restore()
        }
        do {
            let size = try terminalViewport.start()
            try viewHost.start(size: size, mode: options.ui.mode)

            // Long-lived consumers own keyboard bytes, resize events, and timer
            // scheduling. Dispatch producers never spawn a task per event.
            try await withThrowingTaskGroup(of: Void.self) { group in
                defer { stop() }
                group.addTask { @MainActor @Sendable [self] in
                    try await keyboardEventSource.run()
                }
                group.addTask { @MainActor @Sendable [self] in
                    await runLoop.run()
                }
                group.addTask { @MainActor @Sendable [self] in
                    for try await size in terminalViewport.events {
                        guard !isStopping, !Task.isCancelled else { break }
                        try viewHost.resize(to: size)
                    }
                }
                // Observe every result: another task finishing first must not hide
                // failures still awaiting cleanup. Join consumers before restoration.
                for try await _ in group {
                    stop()
                    group.cancelAll()
                }
            }
        } catch {
            stop()
            await terminalViewport.stop()
            throw error
        }
        await terminalViewport.stop()
        if let renderingError { throw renderingError }
    }

    private func presentationFailed(_ error: Error) {
        renderingError = error
        stop()
    }

    private func handle(_ key: KeyEvent) {
        guard !isStopping else { return }
        if key == Self.interruptKey {
            stop()
        } else if !viewHost.handle(key) {
            onKeyEvent?(key)
        }
    }
}

/// Owns the serialized TUI application lifecycle and application-level key policy.
@MainActor
public final class Application {
    /// Configure before run(). Changes during a session do not reconfigure presentation.
    public var options: Application.Options

    /// May be installed, replaced, or cleared while running. Keyboard input and
    /// configured lifecycle shortcuts remain active even when no handler is installed.
    public var onKeyEvent: (@MainActor (KeyEvent) -> Void)?

    private let runLoop: RunLoop
    private let terminalSession: TerminalSession
    private let keyboardEventSource: KeyboardEventSource
    private let viewHost: ViewHost
    private let terminalViewport: TerminalViewport
    private lazy var viewportSource = RunLoopSource { [weak self] in
        self?.viewportSourceFired()
    }
    private var runtimeError: Error?
    private var isStopping = false

    public init(
        rootView: any View,
        runLoop: RunLoop = DefaultRunLoop(),
        terminalSession: TerminalSession = DefaultTerminalSession(),
        keyboardEventSource: KeyboardEventSource? = nil,
        terminalViewport: TerminalViewport = DefaultTerminalViewport()
    ) {
        self.options = Application.Options()
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
            preparePresentation: { mode in try terminalSession.beginPresentation(mode: mode) }
        )
    }

    public func stop() {
        isStopping = true
        keyboardEventSource.stop()
        runLoop.remove(viewportSource)
        terminalViewport.cancel()
        viewHost.stop()
        runLoop.stop()
    }

    /// Owns the terminal until stopped or cancelled. Enabled exit keys request orderly
    /// shutdown regardless of whether an application key handler is installed.
    public func run() async throws {
        guard !isStopping, !Task.isCancelled else {
            stop()
            return
        }
        try terminalSession.start()
        keyboardEventSource.onKeyEvent = { [weak self] key in self?.handle(key) }
        viewHost.onError = { [weak self] error in self?.presentationFailed(error) }
        do {
            let viewportRegistration = runLoop.add(viewportSource)
            let size = try terminalViewport.start(signaling: viewportRegistration)
            try viewHost.start(size: size, mode: options.ui.mode)

            // Keyboard remains a lossless stream consumer. Viewport changes retain only
            // their newest payload and signal the run loop without creating a task per event.
            try await withThrowingTaskGroup(of: Void.self) { group in
                defer { stop() }
                group.addTask { @MainActor @Sendable [self] in
                    try await keyboardEventSource.run()
                }
                group.addTask { @MainActor @Sendable [self] in
                    await runLoop.run()
                }
                // Observe every result: another task finishing first must not hide
                // failures still awaiting cleanup. Join consumers before restoration.
                for try await _ in group {
                    stop()
                    group.cancelAll()
                }
            }
        } catch {
            await finish()
            throw error
        }
        await finish()
        if let runtimeError { throw runtimeError }
    }

    private func finish() async {
        stop()
        await terminalViewport.stop()
        await viewHost.joinTasks()
        viewHost.onError = nil
        keyboardEventSource.onKeyEvent = nil
        terminalSession.restore()
    }

    private func presentationFailed(_ error: Error) {
        fail(error)
    }

    private func viewportSourceFired() {
        guard !isStopping else { return }
        do {
            if let size = try terminalViewport.consume() {
                try viewHost.resize(to: size)
            }
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        if runtimeError == nil { runtimeError = error }
        stop()
    }

    private func handle(_ key: KeyEvent) {
        guard !isStopping else { return }
        if (key == .controlC && options.exitOnControlC) || (key == .controlD && options.exitOnControlD) {
            stop()
        } else if !viewHost.handle(key) {
            onKeyEvent?(key)
        }
    }
}

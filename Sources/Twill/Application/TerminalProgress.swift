/// Controls the terminal emulator's single native progress indicator, not a layout view.
@MainActor
public final class TerminalProgress {
    public enum State: Sendable {
        case hidden
        case indeterminate
    }

    /// The explicit request, hidden by default. Scoped activity remains visible even when
    /// this is hidden. Requests before `Application.run()` are retained without output,
    /// and requests after application shutdown begins do not emit output.
    public var state: State = .hidden {
        didSet { update() }
    }

    private let runLoop: RunLoop
    private let terminalSession: TerminalSession
    private var activities = 0
    private var isRunning = false
    private var isStopped = false
    private var isPresented = false
    private var keepalive: Timer?
    private var keepaliveGeneration: UInt = 0
    var onError: (@MainActor (Error) -> Void)?

    init(runLoop: RunLoop, terminalSession: TerminalSession) {
        self.runLoop = runLoop
        self.terminalSession = terminalSession
    }

    /// Keeps progress visible until this operation exits. Overlapping scopes are independent.
    /// Cancellation releases activity when the operation cooperatively unwinds.
    public func withActivity<Result>(
        _ operation: @MainActor () async throws -> Result
    ) async rethrows -> Result {
        activities += 1
        update()
        defer {
            activities -= 1
            update()
        }
        return try await operation()
    }

    func start() {
        guard !isStopped else { return }
        isRunning = true
        update()
    }

    func stop() {
        isStopped = true
        isRunning = false
        cancelKeepalive()
        // The session clears progress after Application joins its owned tasks.
    }

    private func update() {
        guard isRunning else { return }
        let active = state == .indeterminate || activities > 0
        guard active != isPresented else { return }
        do {
            try terminalSession.setProgress(active: active)
            isPresented = active
            if active {
                let generation = keepaliveGeneration
                let timer = Timer(interval: .seconds(1), repeats: true) { [weak self] in
                    guard let self, self.keepaliveGeneration == generation else { return }
                    self.refresh()
                }
                keepalive = timer
                runLoop.add(timer)
            } else {
                cancelKeepalive()
            }
        } catch {
            stop()
            onError?(error)
        }
    }

    private func refresh() {
        guard isRunning, isPresented, keepalive?.isCancelled == false else { return }
        do {
            try terminalSession.setProgress(active: true)
        } catch {
            stop()
            onError?(error)
        }
    }

    private func cancelKeepalive() {
        keepaliveGeneration &+= 1
        if let keepalive { runLoop.cancel(keepalive) }
        keepalive = nil
    }
}

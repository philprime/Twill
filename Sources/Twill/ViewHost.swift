import Foundation

/// Owns mounted content, cell-frame buffering, viewport layout, and the next
/// timeline wake-up. Terminal ownership is delegated to the session.
@MainActor
final class ViewHost {
    var onError: ((Error) -> Void)?
    private let rootView: any View
    private let runLoop: RunLoop
    private let presenter: TerminalPresenter
    private var viewportSize: TerminalSize?
    private let now: () -> Date
    private var renderer: ViewRenderer?
    private var timer: Timer?
    private var scheduledDate: Date?
    private var stateTimer: Timer?
    private var isActive = false

    init(
        rootView: any View, runLoop: RunLoop, output: TerminalOutput,
        preparePresentation: @escaping () throws -> Void = {},
        now: @escaping () -> Date = { .now }
    ) {
        self.rootView = rootView
        self.runLoop = runLoop
        presenter = TerminalPresenter(output: output, preparePresentation: preparePresentation)
        self.now = now
    }

    func start(size: TerminalSize? = nil, mode: UIMode = .inline) throws {
        presenter.mode = mode
        // Body evaluation belongs to the running session, not application construction.
        let renderer = ViewRenderer.make(rootView)
        renderer.onInvalidation = { [weak self] in self?.requestPresentation() }
        self.renderer = renderer
        isActive = true
        viewportSize = size
        do {
            try render()
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        isActive = false
        cancelTimer()
        if let stateTimer { runLoop.cancel(stateTimer) }
        stateTimer = nil
        renderer = nil
        presenter.stop()
    }

    private func cancelTimer() {
        if let timer { runLoop.cancel(timer) }
        timer = nil
        scheduledDate = nil
    }

    private func requestPresentation() {
        guard isActive, stateTimer == nil else { return }
        // State writes share one wake-up; the independent timeline timer remains armed.
        let pending = Timer(deadline: .now()) { [weak self] in
            guard let self else { return }
            self.stateTimer = nil
            do {
                try render()
            } catch {
                stop()
                onError?(error)
            }
        }
        stateTimer = pending
        runLoop.add(pending)
    }

    private var proposal: ProposedCellSize {
        ProposedCellSize(width: viewportSize?.columns, height: viewportSize?.rows)
    }

    func handle(_ key: KeyEvent) -> Bool {
        guard isActive, let renderer else { return false }
        // A prior key may have changed mounted state while its presentation is
        // still coalesced. Route this key through the current scope immediately.
        if stateTimer != nil { renderer.refreshContent(at: now()) }
        return renderer.handle(key)
    }

    func resize(to size: TerminalSize) throws {
        guard isActive, let renderer, size != viewportSize else { return }
        viewportSize = size
        // Terminal reflow invalidates the physical baseline. Resize only draws
        // cached content, leaving all timeline deadlines and timers untouched.
        let frame = renderer.drawFrame(proposal: proposal)
        try presenter.present(FrameSnapshot(grid: frame, caret: renderer.caretPosition), invalidate: true)
    }

    private func render() throws {
        guard isActive, let renderer else { return }
        // A due timeline can consume pending state work in the same frame.
        if let stateTimer { runLoop.cancel(stateTimer) }
        stateTimer = nil
        let frame = renderer.render(now(), proposal: proposal)
        try presenter.present(FrameSnapshot(grid: frame.grid, caret: renderer.caretPosition))
        guard isActive else { return }
        // Parent state updates must not restart an unchanged child's deadline.
        guard scheduledDate != frame.nextUpdate || timer == nil else { return }
        cancelTimer()
        guard let next = frame.nextUpdate else { return }
        let timer = Timer(deadline: .now() + max(0, next.timeIntervalSince(now()))) { [weak self] in
            guard let self else { return }
            self.timer = nil
            self.scheduledDate = nil
            do {
                try render()
            } catch {
                stop()
                onError?(error)
            }
        }
        self.timer = timer
        scheduledDate = next
        runLoop.add(timer)
    }
}

import Foundation

/// Owns mounted content, cell-frame buffering, viewport layout, and the next
/// timeline wake-up. Presentation remains inline rather than owning the whole screen.
@MainActor
final class ViewHost {
    private static let hideCursor = "\u{1B}[?25l"
    private static let showCursor = "\u{1B}[?25h"

    var onError: ((Error) -> Void)?
    private let rootView: any View
    private let runLoop: RunLoop
    private let output: TerminalOutput
    private let preparePresentation: () throws -> Void
    private var viewportSize: TerminalSize?
    private let now: () -> Date
    private var renderer: ViewRenderer?
    private var timer: Timer?
    private var scheduledDate: Date?
    private var stateTimer: Timer?
    private var isActive = false
    private var hasRendered = false
    private var lastFrame: CellGrid?
    private var lastCaret: CellPosition?

    init(
        rootView: any View, runLoop: RunLoop, output: TerminalOutput,
        preparePresentation: @escaping () throws -> Void = {},
        now: @escaping () -> Date = { .now }
    ) {
        self.rootView = rootView
        self.runLoop = runLoop
        self.output = output
        self.preparePresentation = preparePresentation
        self.now = now
    }

    func start(size: TerminalSize? = nil) throws {
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
        if hasRendered {
            // Multi-row writes leave the hidden cursor at the frame's top-left.
            // Finish below the frame before restoring the borrowed shell cursor.
            let finish: String
            if let height = lastFrame?.size.height, height > 1 {
                finish = "\u{1B}[\(height - 1)B\r\n"
            } else {
                finish = "\n"
            }
            // Finishing the presentation must not replace an earlier output error.
            try? output.write(returnToFrame() + finish)
        }
        hasRendered = false
        lastFrame = nil
        lastCaret = nil
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

    private func returnToFrame() -> String {
        guard let lastCaret else { return "" }
        var output = Self.hideCursor + "\r"
        if lastCaret.row > 0 { output += "\u{1B}[\(lastCaret.row)A" }
        return output
    }

    private func showCaret(at caret: CellPosition) -> String {
        var output = "\r"
        if caret.row > 0 { output += "\u{1B}[\(caret.row)B" }
        if caret.column > 0 { output += "\u{1B}[\(caret.column)C" }
        return output + Self.showCursor
    }

    private func present(_ frame: CellGrid?, caret: CellPosition?, invalidate: Bool = false) throws {
        let cells = InlineFrameEncoder.encode(frame, previous: lastFrame, invalidate: invalidate)
        var buffer = ""
        if lastCaret != nil, !cells.isEmpty || caret != lastCaret { buffer += returnToFrame() }
        buffer += cells
        if let caret, !cells.isEmpty || caret != lastCaret { buffer += showCaret(at: caret) }
        if !buffer.isEmpty {
            if !hasRendered { try preparePresentation() }
            try output.write(buffer)
            hasRendered = true
        }
        // Failed writes must never advance either physical baseline.
        lastFrame = frame
        lastCaret = caret
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
        try present(frame, caret: renderer.caretPosition, invalidate: true)
    }

    private func render() throws {
        guard isActive, let renderer else { return }
        // A due timeline can consume pending state work in the same frame.
        if let stateTimer { runLoop.cancel(stateTimer) }
        stateTimer = nil
        let frame = renderer.render(now(), proposal: proposal)
        try present(frame.grid, caret: renderer.caretPosition)
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

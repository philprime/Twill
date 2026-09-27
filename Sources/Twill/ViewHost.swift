import Foundation

/// Owns mounted content, cell-frame buffering, viewport layout, and the next
/// timeline wake-up. Presentation remains inline rather than owning the whole screen.
@MainActor
final class ViewHost {
    var onError: ((Error) -> Void)?
    private let rootView: any View
    private let runLoop: RunLoop
    private let output: TerminalOutput
    private let preparePresentation: () throws -> Void
    private var viewportSize: TerminalSize?
    private let now: () -> Date
    private var renderer: ViewRenderer?
    private var timer: Timer?
    private var isActive = false
    private var hasRendered = false
    private var lastFrame: CellGrid?

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
        renderer = ViewRenderer.make(rootView)
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
        renderer = nil
        if hasRendered {
            // Finishing the presentation must not replace an earlier output error.
            try? output.write("\n")
        }
        hasRendered = false
        lastFrame = nil
    }

    private func cancelTimer() {
        if let timer { runLoop.cancel(timer) }
        timer = nil
    }

    private func present(_ frame: CellGrid?, invalidate: Bool = false) throws {
        let buffer = InlineFrameEncoder.encode(frame, previous: lastFrame, invalidate: invalidate)
        if !buffer.isEmpty {
            if !hasRendered { try preparePresentation() }
            try output.write(buffer)
            hasRendered = true
        }
        // Failed writes must never advance the diff baseline.
        lastFrame = frame
    }

    private var proposal: ProposedCellSize {
        ProposedCellSize(width: viewportSize?.columns, height: viewportSize?.rows)
    }

    func resize(to size: TerminalSize) throws {
        guard isActive, let renderer, size != viewportSize else { return }
        viewportSize = size
        // Terminal reflow invalidates the physical baseline. Resize only draws
        // cached content, leaving all timeline deadlines and timers untouched.
        try present(renderer.drawFrame(proposal: proposal), invalidate: true)
    }

    private func render() throws {
        guard isActive, let renderer else { return }
        let frame = renderer.render(now(), proposal: proposal)
        try present(frame.grid)
        guard isActive, let next = frame.nextUpdate else { return }
        let timer = Timer(deadline: .now() + max(0, next.timeIntervalSince(now()))) { [weak self] in
            guard let self else { return }
            self.timer = nil
            do {
                try render()
            } catch {
                stop()
                onError?(error)
            }
        }
        self.timer = timer
        runLoop.add(timer)
    }
}

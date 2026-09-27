import Foundation

/// Owns one mounted root and its next presentation deadline. This initial presenter
/// redraws one terminal line; cell layout, wrapping, and full-screen rendering are deferred.
@MainActor
final class ViewHost {
    private static let clearLine = "\r\u{1B}[2K"

    var onError: ((Error) -> Void)?
    private let rootView: any View
    private let runLoop: RunLoop
    private let output: TerminalOutput
    private let now: () -> Date
    private var renderer: ViewRenderer?
    private var timer: Timer?
    private var isActive = false
    private var hasRendered = false
    private var lastText: String?

    init(rootView: any View, runLoop: RunLoop, output: TerminalOutput, now: @escaping () -> Date = { .now }) {
        self.rootView = rootView
        self.runLoop = runLoop
        self.output = output
        self.now = now
    }

    func start() throws {
        // Body evaluation belongs to the running session, not application construction.
        renderer = ViewRenderer.make(rootView)
        isActive = true
        try render()
    }

    func stop() {
        isActive = false
        cancelTimer()
        renderer = nil
        if hasRendered {
            // Cleanup must not replace an earlier rendering error or skip terminal restoration.
            try? output.write("\n")
            hasRendered = false
        }
        lastText = nil
    }

    private func cancelTimer() {
        if let timer { runLoop.cancel(timer) }
        timer = nil
    }

    private func render() throws {
        guard isActive, let renderer else { return }
        let frame = renderer.render(now())
        if frame.text != lastText {
            // Text is data, not ANSI. Control characters must not inject terminal commands.
            let sanitized = String(
                (frame.text ?? "").unicodeScalars.map {
                    $0.properties.generalCategory == .control ? Character(" ") : Character(String($0))
                })
            try output.write(Self.clearLine + sanitized)
            // Only successfully written content becomes the presentation baseline.
            lastText = frame.text
            hasRendered = true
        }
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

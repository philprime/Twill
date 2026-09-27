/// Owns the terminal's last successfully written frame and its output.
@MainActor
final class TerminalPresenter {
    private static let hideCursor = "\u{1B}[?25l"
    private static let showCursor = "\u{1B}[?25h"

    var mode: UIMode
    private let output: TerminalOutput
    private let preparePresentation: () throws -> Void
    private var hasRendered = false
    private var lastFrame: CellGrid?
    private var lastCaret: CellPosition?

    init(output: TerminalOutput, mode: UIMode = .inline, preparePresentation: @escaping () throws -> Void = {}) {
        self.mode = mode
        self.output = output
        self.preparePresentation = preparePresentation
    }

    func present(_ snapshot: FrameSnapshot, invalidate: Bool = false) throws {
        let cells = InlineFrameEncoder.encode(
            snapshot.grid, previous: lastFrame, invalidate: invalidate, fullscreen: mode == .fullscreen
        )
        var buffer = ""
        if mode == .fullscreen, !cells.isEmpty, !hasRendered || invalidate {
            buffer += "\u{1B}[2J"
        }
        if mode == .fullscreen, !cells.isEmpty {
            buffer += "\u{1B}[H"
        } else if lastCaret != nil, !cells.isEmpty || snapshot.caret != lastCaret {
            buffer += returnToFrame()
        }
        buffer += cells
        if let caret = snapshot.caret, !cells.isEmpty || caret != lastCaret {
            buffer += showCaret(at: caret)
        }
        if !buffer.isEmpty {
            if !hasRendered { try preparePresentation() }
            try output.write(buffer)
            hasRendered = true
        }
        // Failed writes must never advance the physical baseline.
        lastFrame = snapshot.grid
        lastCaret = snapshot.caret
    }

    func stop() {
        if hasRendered, mode == .inline {
            // Multi-row writes leave the hidden cursor at the frame's top-left.
            // Finish below the frame before restoring the borrowed shell cursor.
            let finish: String
            if let height = lastFrame?.size.height, height > 1 {
                finish = "\u{1B}[\(height - 1)B\r\n"
            } else {
                finish = "\n"
            }
            // Finishing must not replace an earlier output error.
            try? output.write(returnToFrame() + finish)
        }
        hasRendered = false
        lastFrame = nil
        lastCaret = nil
    }

    private func returnToFrame() -> String {
        guard let lastCaret else { return "" }
        if mode == .fullscreen { return Self.hideCursor + "\u{1B}[H" }
        var buffer = Self.hideCursor + "\r"
        if lastCaret.row > 0 { buffer += "\u{1B}[\(lastCaret.row)A" }
        return buffer
    }

    private func showCaret(at caret: CellPosition) -> String {
        if mode == .fullscreen {
            return "\u{1B}[\(caret.row + 1);\(caret.column + 1)H" + Self.showCursor
        }
        var buffer = "\r"
        if caret.row > 0 { buffer += "\u{1B}[\(caret.row)B" }
        if caret.column > 0 { buffer += "\u{1B}[\(caret.column)C" }
        return buffer + Self.showCursor
    }
}

/// Owns the terminal's last successfully written frame and its output.
@MainActor
final class TerminalPresenter {
    private static let hideCursor = "\u{1B}[?25l"
    private static let showCursor = "\u{1B}[?25h"

    var mode: Application.Options.UIOptions.Mode
    private let output: TerminalOutput
    private let preparePresentation: (Application.Options.UIOptions.Mode) throws -> Void
    private var hasRendered = false
    private var lastFrame: CellGrid?
    private var lastCaret: CellPosition?
    private let imageIDBase = UInt32.random(in: 1...(UInt32.max / 2))
    private var ownedImageCount = 0

    private func deleteImages() -> String {
        (0..<ownedImageCount).map { KittyImageEncoder.delete(id: imageIDBase + UInt32($0)) }.joined()
    }

    init(
        output: TerminalOutput, mode: Application.Options.UIOptions.Mode = .inline,
        preparePresentation: @escaping (Application.Options.UIOptions.Mode) throws -> Void = { _ in }
    ) {
        self.mode = mode
        self.output = output
        self.preparePresentation = preparePresentation
    }

    func present(_ snapshot: FrameSnapshot, invalidate: Bool = false) throws {
        let cells = InlineFrameEncoder.encode(
            snapshot.grid, previous: lastFrame, invalidate: invalidate, fullscreen: mode == .fullscreen
        )
        let images = snapshot.grid?.images ?? []
        let redrawImages = invalidate || images != (lastFrame?.images ?? []) || !cells.isEmpty
        let imageChanges = redrawImages && (!images.isEmpty || ownedImageCount > 0)
        let hasUpdates = !cells.isEmpty || imageChanges
        var buffer = imageChanges ? deleteImages() : ""
        if mode == .fullscreen, hasUpdates, !hasRendered || invalidate {
            buffer += "\u{1B}[2J"
        }
        if mode == .fullscreen, hasUpdates {
            buffer += "\u{1B}[H"
        } else if lastCaret != nil, hasUpdates || snapshot.caret != lastCaret {
            buffer += returnToFrame()
        }
        buffer += cells
        if imageChanges {
            for (index, image) in images.enumerated() {
                buffer += KittyImageEncoder.display(image, id: imageIDBase + UInt32(index))
            }
            // A write may fail after transmitting a prefix. Retain every attempted
            // ID for cleanup even though the successful frame baseline stays unchanged.
            ownedImageCount = max(ownedImageCount, images.count)
        }
        if let caret = snapshot.caret, hasUpdates || caret != lastCaret {
            buffer += showCaret(at: caret)
        } else if mode == .fullscreen, hasUpdates {
            // Fullscreen redraws return the hardware cursor home. Hide it after
            // drawing instead of relying on the session's earlier hide command.
            buffer += Self.hideCursor
        }
        if !buffer.isEmpty {
            if !hasRendered { try preparePresentation(mode) }
            try output.write(buffer)
            hasRendered = true
        }
        // Failed writes must never advance the physical baseline.
        if imageChanges { ownedImageCount = images.count }
        lastFrame = snapshot.grid
        lastCaret = snapshot.caret
    }

    func stop() {
        if ownedImageCount > 0 { try? output.write(deleteImages()) }
        ownedImageCount = 0
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

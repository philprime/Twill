import Testing

@testable import Twill

@Suite("Committed terminal presentation")
@MainActor
struct TerminalPresenterTests {
    @Test("A failed write keeps the last successful frame as the diff baseline")
    func failedWriteBaseline() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let presenter = TerminalPresenter(output: output)
        var first = CellGrid(size: CellSize(width: 1, height: 1))
        first.put("A", width: 1, column: 0, row: 0)
        var second = CellGrid(size: CellSize(width: 1, height: 1))
        second.put("B", width: 1, column: 0, row: 0)
        try presenter.present(FrameSnapshot(grid: first, caret: nil))
        output.nextFailure = PresentationFailure.failed

        // -- Act --
        #expect(throws: PresentationFailure.self) {
            try presenter.present(FrameSnapshot(grid: second, caret: nil))
        }
        try presenter.present(FrameSnapshot(grid: first, caret: nil))
        presenter.stop()

        // -- Assert --
        #expect(output.writes == ["\r\u{1B}[2KA", "\n"])
    }

    @Test("An unchanged committed frame produces no additional output")
    func unchangedFrame() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let presenter = TerminalPresenter(output: output)
        var grid = CellGrid(size: CellSize(width: 1, height: 1))
        grid.put("A", width: 1, column: 0, row: 0)
        let frame = FrameSnapshot(grid: grid, caret: nil)

        // -- Act --
        try presenter.present(frame)
        try presenter.present(frame)
        presenter.stop()

        // -- Assert --
        #expect(output.writes == ["\r\u{1B}[2KA", "\n"])
    }

    @Test("Fullscreen frames stay anchored without reserving shell rows")
    func fullscreenFrame() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let presenter = TerminalPresenter(output: output, mode: .fullscreen)
        var grid = CellGrid(size: CellSize(width: 2, height: 2))
        grid.put("A", width: 1, column: 0, row: 0)
        grid.put("B", width: 1, column: 0, row: 1)

        // -- Act --
        try presenter.present(FrameSnapshot(grid: grid, caret: nil))
        presenter.stop()

        // -- Assert --
        #expect(output.writes == ["\u{1B}[2J\u{1B}[H\r\u{1B}[2KA \r\u{1B}[1B\r\u{1B}[2KB \r\u{1B}[1A\u{1B}[?25l"])
    }

    @Test("Removing a fullscreen caret hides the cursor without changing cells")
    func removeFullscreenCaret() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let presenter = TerminalPresenter(output: output, mode: .fullscreen)
        var grid = CellGrid(size: CellSize(width: 1, height: 1))
        grid.put("A", width: 1, column: 0, row: 0)
        try presenter.present(FrameSnapshot(grid: grid, caret: CellPosition(column: 0, row: 0)))

        // -- Act --
        try presenter.present(FrameSnapshot(grid: grid, caret: nil))

        // -- Assert --
        #expect(output.writes.count == 2)
        #expect(output.writes.last == "\u{1B}[?25l\u{1B}[H")
    }

    private enum PresentationFailure: Error { case failed }
}

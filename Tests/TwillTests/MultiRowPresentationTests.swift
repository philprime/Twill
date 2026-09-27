import Foundation
import Testing

@testable import Twill

@Suite("Multi-row inline presentation")
@MainActor
struct MultiRowPresentationTests {
    @Test("Stopping a multi-row host leaves the shell cursor below the frame")
    func multiRowShutdown() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: VStack {
                Text("Head")
                Text("Body")
            }, runLoop: RecordingRunLoop(), output: output
        )

        // -- Act --
        try host.start()
        host.stop()

        // -- Assert --
        #expect(output.writes.first?.contains("Head") == true)
        #expect(output.writes.first?.contains("Body") == true)
        #expect(output.writes.last == "\u{1B}[1B\r\n")
    }

    @Test("Resizing a multi-row frame clips and restores rows without evaluating bodies")
    func resizeRows() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let output = RecordingTerminalOutput()
        let runLoop = RecordingRunLoop()
        var evaluations = 0
        let root = TimelineView(.periodic(from: start, by: 1)) { _ in
            evaluations += 1
            return VStack {
                Text("Top")
                Text("Bot")
            }
        }
        let host = ViewHost(rootView: root, runLoop: runLoop, output: output, now: { start })
        try host.start(size: TerminalSize(columns: 3, rows: 2))

        // -- Act --
        try host.resize(to: TerminalSize(columns: 3, rows: 1))
        try host.resize(to: TerminalSize(columns: 3, rows: 2))
        let cancelledBeforeStop = runLoop.cancelled.count
        host.stop()

        // -- Assert --
        #expect(evaluations == 1)
        #expect(cancelledBeforeStop == 0)
        #expect(output.writes.count == 4)
        #expect(output.writes[1].contains("\u{1B}[2K"))
        #expect(output.writes[2].contains("Bot"))
        #expect(output.writes.last == "\u{1B}[1B\r\n")
    }

    @Test("Only changed rows are updated, and removed rows are cleared")
    func rowUpdates() {
        // -- Arrange --
        let initial = grid(["A", "B"])
        let updated = grid(["A", "C"])
        let shortened = grid(["A"])

        // -- Act --
        let first = InlineFrameEncoder.encode(initial, previous: nil)
        let changed = InlineFrameEncoder.encode(updated, previous: initial)
        let unchanged = InlineFrameEncoder.encode(updated, previous: updated)
        let removed = InlineFrameEncoder.encode(shortened, previous: updated)
        let cleared = InlineFrameEncoder.encode(nil, previous: updated)

        // -- Assert --
        #expect(first.contains("\u{1B}[2KA"))
        #expect(first.contains("\u{1B}[2KB"))
        #expect(changed == "\r\u{1B}[1B\rC\r\u{1B}[1A")
        #expect(unchanged.isEmpty)
        #expect(removed == "\r\u{1B}[1B\r\u{1B}[2K\r\u{1B}[1A")
        #expect(cleared == "\r\u{1B}[2K\r\u{1B}[1B\r\u{1B}[2K\r\u{1B}[1A")
    }

    @Test("Growing a frame redraws its rows after reserving terminal space")
    func growingFrame() {
        // -- Arrange --
        let initial = grid(["A", "B"])
        let expanded = grid(["A", "B", "C"])

        // -- Act --
        let output = InlineFrameEncoder.encode(expanded, previous: initial)

        // -- Assert --
        #expect(output.hasPrefix("\r\u{1B}[1B\r\n\r\u{1B}[2A"))
        #expect(output.contains("\u{1B}[2KA"))
        #expect(output.contains("\u{1B}[2KB"))
        #expect(output.contains("\u{1B}[2KC"))
        #expect(output.hasSuffix("\r\u{1B}[2A"))
    }

    @Test("Arrow focus changes redraw styled cells on separate rows")
    func verticalFocus() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack {
                Text("One").focusable()
                Text("Two").focusable()
            })
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        let updated = try #require(renderer.drawFrame(proposal: .unspecified))
        let output = InlineFrameEncoder.encode(updated, previous: initial)

        // -- Assert --
        #expect(initial.isFocused(column: 0, row: 0))
        #expect(!updated.isFocused(column: 0, row: 0))
        #expect(updated.isFocused(column: 0, row: 1))
        #expect(output.contains("\u{1B}[7mTwo\u{1B}[27m"))
        #expect(output.hasSuffix("\r\u{1B}[1A"))
    }

    @Test("Reverse video ends before drawing an unfocused row")
    func focusedRow() {
        // -- Arrange --
        var frame = CellGrid(size: CellSize(width: 1, height: 2))
        frame.put("A", width: 1, column: 0, row: 0, focused: true)
        frame.put("B", width: 1, column: 0, row: 1)

        // -- Act --
        let output = InlineFrameEncoder.encode(frame, previous: nil)

        // -- Assert --
        #expect(output.contains("\u{1B}[7mA\u{1B}[27m"))
        #expect(!output.contains("\u{1B}[7mB"))
    }

    private func grid(_ rows: [String]) -> CellGrid {
        let width = rows.map { TextDrawing($0).sizeThatFits(.unspecified).width }.max() ?? 0
        var context = DrawingContext(size: CellSize(width: width, height: rows.count))
        for (row, value) in rows.enumerated() {
            context.withRegion(CellRect(column: 0, row: row, width: width, height: 1)) {
                TextDrawing(value).draw(in: &$0)
            }
        }
        return context.grid
    }
}

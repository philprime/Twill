import Foundation
import Testing

@testable import Twill

@Suite("Canvas")
@MainActor
struct CanvasTests {
    @Test("Canvas fills the proposed space and clips individual cells")
    func drawing() {
        // -- Arrange --
        var receivedSize: CanvasSize?
        let renderer = ViewRenderer.make(
            Canvas { context, size in
                receivedSize = size
                context.draw("X", column: 1, row: 1, foreground: Color(red: 10, green: 20, blue: 30))
                context.draw("Y", column: 3, row: 1)
            })

        // -- Act --
        let frame = renderer.render(Date(timeIntervalSinceReferenceDate: 100), proposal: .init(width: 3, height: 2))

        // -- Assert --
        #expect(receivedSize == CanvasSize(width: 3, height: 2))
        #expect(frame.nextUpdate == nil)
        #expect(frame.grid?.size == CellSize(width: 3, height: 2))
        #expect(frame.grid?[1, 1] == .glyph("X", width: 1))
        #expect(frame.grid?.foreground(column: 1, row: 1) == Color(red: 10, green: 20, blue: 30))
        #expect(frame.grid?[2, 1] == .blank)
    }

    @Test("Buffer copying preserves transparent cells and clips wide glyphs")
    func buffer() {
        // -- Arrange --
        var image = CanvasBuffer(size: CanvasSize(width: 3, height: 1))
        image[0, 0] = CanvasCell("A", foreground: Color(red: 1, green: 2, blue: 3))
        image[2, 0] = CanvasCell("界")
        let renderer = ViewRenderer.make(
            Canvas { context, _ in
                context.render(image, column: 1, row: 0)
            })

        // -- Act --
        let frame = renderer.render(.now, proposal: .init(width: 4, height: 1))

        // -- Assert --
        #expect(frame.grid?[1, 0] == .glyph("A", width: 1))
        #expect(frame.grid?.foreground(column: 1, row: 0) == Color(red: 1, green: 2, blue: 3))
        #expect(frame.grid?[2, 0] == .blank)
        #expect(frame.grid?[3, 0] == .blank)
    }

    @Test("Wide buffer glyphs do not spill beyond the copied image")
    func wideBufferEdge() {
        // -- Arrange --
        var image = CanvasBuffer(size: CanvasSize(width: 1, height: 1))
        image[0, 0] = CanvasCell("界")
        let renderer = ViewRenderer.make(
            Canvas { context, _ in
                context.render(image, column: 1, row: 0)
            })

        // -- Act --
        let frame = renderer.render(.now, proposal: .init(width: 4, height: 1))

        // -- Assert --
        #expect(frame.grid?[1, 0] == .blank)
        #expect(frame.grid?[2, 0] == .blank)
    }

    @Test("Removing a scheduled canvas drops its deadline")
    func removedCanvas() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let root = TimelineView(.periodic(from: start, by: 1)) { parent in
            HStack {
                if parent.date == start {
                    Canvas(interval: 0.25) { context, _ in
                        context.draw("X", column: 0, row: 0)
                    }
                }
                Text("!")
            }
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        let first = renderer.render(start, proposal: .init(width: 3, height: 1))
        let removed = renderer.render(start.addingTimeInterval(1), proposal: .init(width: 3, height: 1))

        // -- Assert --
        #expect(first.nextUpdate == start.addingTimeInterval(0.25))
        #expect(removed.grid?.snapshotText == "!")
        #expect(removed.nextUpdate == start.addingTimeInterval(2))
    }

    @Test("Unchanged scheduled canvas requests frames without rewriting terminal output")
    func unchangedCanvasOutput() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let root = Canvas(interval: 0.05) { context, _ in
            context.draw("X", column: 0, row: 0)
        }
        let host = ViewHost(rootView: root, runLoop: runLoop, output: output, now: { now })
        try host.start(size: TerminalSize(columns: 2, rows: 1))

        // -- Act --
        let initialWrites = output.writes.count
        now = start.addingTimeInterval(0.05)
        try #require(runLoop.timers.last).action()
        let writesAfterTick = output.writes.count
        host.stop()

        // -- Assert --
        #expect(initialWrites == 1)
        #expect(writesAfterTick == initialWrites)
        #expect(runLoop.timers.count == 2)
    }

    @Test("Scheduled canvas retains phase across parent updates and clears prior frames")
    func scheduling() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var mark = "A"
        let root = TimelineView(.periodic(from: start, by: 0.5)) { _ in
            Canvas(interval: 1) { context, _ in
                context.draw(mark.first!, column: context.date == start ? 0 : 1, row: 0)
            }
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        let first = renderer.render(start, proposal: .init(width: 2, height: 1))
        mark = "B"
        let parent = renderer.render(start.addingTimeInterval(0.5), proposal: .init(width: 2, height: 1))
        let due = renderer.render(start.addingTimeInterval(1), proposal: .init(width: 2, height: 1))

        // -- Assert --
        #expect(first.nextUpdate == start.addingTimeInterval(0.5))
        #expect(parent.grid?.snapshotText == "B ")
        #expect(due.grid?.snapshotText == " B")
        #expect(due.nextUpdate == start.addingTimeInterval(1.5))
    }
}

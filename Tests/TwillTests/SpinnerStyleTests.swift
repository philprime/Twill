import Foundation
import Testing

@testable import Twill

@Suite("Spinner styles")
@MainActor
struct SpinnerStyleTests {
    @Test(
        "Built-in and custom styles animate within a single cell",
        arguments: [
            (SpinnerStyle.dots, "⠋", "⠙"),
            (.arc, "◜", "◝"),
            (.line, "|", "/"),
            (.custom(.init(["○", "●"])), "○", "●"),
        ])
    func animation(style: SpinnerStyle, first: String, next: String) {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(ProgressView(spinnerStyle: style))

        // -- Act --
        let initial = renderer.render(start)
        let advanced = renderer.render(start.addingTimeInterval(0.1))

        // -- Assert --
        #expect(initial.grid?.snapshotText == first)
        #expect(advanced.grid?.snapshotText == next)
        #expect(advanced.grid?.size == CellSize(width: 1, height: 1))
        #expect(advanced.nextUpdate == start.addingTimeInterval(0.2))
    }

    @Test("Style selection works with both text and custom labels")
    func labels() {
        // -- Arrange --
        let title = ViewRenderer.make(ProgressView("Loading", spinnerStyle: .arc))
        let custom = ViewRenderer.make(ProgressView(spinnerStyle: .line) { Text("Waiting") })
        let start = Date(timeIntervalSinceReferenceDate: 100)

        // -- Act --
        let titleFrame = title.render(start)
        let customFrame = custom.render(start)

        // -- Assert --
        #expect(titleFrame.grid?.snapshotText == "◜ Loading")
        #expect(customFrame.grid?.snapshotText == "| Waiting")
    }

    @Test("Changing style preserves the mounted animation date and deadline")
    func styleChange() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let root = TimelineView(.periodic(from: start, by: 0.05)) { context in
            ProgressView(spinnerStyle: context.date == start ? .line : .arc)
        }
        let renderer = ViewRenderer.make(root)
        _ = renderer.render(start)

        // -- Act --
        let parent = renderer.render(start.addingTimeInterval(0.05))
        let tick = renderer.render(start.addingTimeInterval(0.1))

        // -- Assert --
        #expect(parent.grid?.snapshotText == "◜")
        #expect(tick.grid?.snapshotText == "◝")
    }

    @Test("Spinner style does not animate determinate progress")
    func determinate() {
        // -- Arrange --
        let renderer = ViewRenderer.make(ProgressView(value: 0.5, spinnerStyle: .arc))

        // -- Act --
        let frame = renderer.render(.init(timeIntervalSinceReferenceDate: 100), proposal: .init(width: 4, height: 1))

        // -- Assert --
        #expect(frame.grid?.snapshotText == "━━──")
        #expect(frame.nextUpdate == nil)
    }
}

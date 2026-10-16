import Foundation
import Testing

@testable import Twill

@Suite("Progress view")
@MainActor
struct ProgressViewTests {
    @Test("Determinate progress fills the proposed width without scheduling updates")
    func determinate() {
        // -- Arrange --
        let renderer = ViewRenderer.make(ProgressView(value: 3, total: 4))

        // -- Act --
        let frame = renderer.render(.init(timeIntervalSinceReferenceDate: 100), proposal: .init(width: 8, height: 3))

        // -- Assert --
        #expect(frame.grid?.snapshotText == "━━━━━━──")
        #expect(frame.grid?.size == CellSize(width: 8, height: 1))
        #expect(frame.nextUpdate == nil)
    }

    @Test(
        "Values are pinned to the progress range",
        arguments: [
            (-1.0, "────────"), (0, "────────"), (0.5, "━━━━────"),
            (1, "━━━━━━━━"), (2, "━━━━━━━━"), (.infinity, "━━━━━━━━"),
            (-.infinity, "────────"), (.nan, "────────"),
        ])
    func bounds(value: Double, expected: String) {
        // -- Arrange --
        let renderer = ViewRenderer.make(ProgressView(value: value))

        // -- Act --
        let frame = renderer.render(.init(timeIntervalSinceReferenceDate: 100), proposal: .init(width: 8, height: 1))

        // -- Assert --
        #expect(frame.grid?.snapshotText == expected)
        #expect(frame.nextUpdate == nil)
    }

    @Test("Labels compose above the bar and preserve concrete custom content")
    func labels() {
        // -- Arrange --
        let text = ViewRenderer.make(ProgressView("Loading", value: 0.5))
        let custom = ViewRenderer.make(
            ProgressView(value: 0.5) {
                HStack {
                    Text("Files")
                    Text("2/4")
                }
            })
        let date = Date(timeIntervalSinceReferenceDate: 100)

        // -- Act --
        let textFrame = text.render(date, proposal: .init(width: 8, height: 2))
        let customFrame = custom.render(date, proposal: .init(width: 9, height: 2))

        // -- Assert --
        #expect(textFrame.grid?.snapshotText == "Loading \n━━━━────")
        #expect(customFrame.grid?.snapshotText == "Files 2/4\n━━━━─────")
    }

    @Test("An unconstrained bar has a useful intrinsic width and zero-width proposals are safe")
    func sizing() {
        // -- Arrange --
        let renderer = ViewRenderer.make(ProgressView(value: 0.5))
        let date = Date(timeIntervalSinceReferenceDate: 100)

        // -- Act --
        let intrinsic = renderer.render(date)
        let empty = renderer.render(date, proposal: .init(width: 0, height: 0))

        // -- Assert --
        #expect(intrinsic.grid?.snapshotText == "━━━━━━━━━━──────────")
        #expect(empty.grid?.size == .zero)
    }
}

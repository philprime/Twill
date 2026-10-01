import Foundation
import Testing

@testable import Twill

@Suite("Adaptive grid columns")
@MainActor
struct AdaptiveGridTests {
    @Test("Adaptive columns fit as many minimum-width cells as the container allows")
    func adaptiveColumns() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 3))], spacing: 1) {
                Text("A")
                Text("B")
                Text("C")
                Text("D")
            }
        )

        // -- Act --
        let wide = renderer.render(.now, proposal: ProposedCellSize(width: 11))
        let narrow = renderer.render(.now, proposal: ProposedCellSize(width: 7))
        let tiny = renderer.render(.now, proposal: ProposedCellSize(width: 2))

        // -- Assert --
        #expect(wide.grid?.snapshotText == "A   B   C  \n           \nD          ")
        #expect(narrow.grid?.snapshotText == "A   B  \n       \nC   D  ")
        #expect(tiny.grid?.snapshotText == "A \n  \nB \n  \nC \n  \nD ")
    }

    @Test("Resizing an adaptive grid reflows mounted content without reevaluating its body")
    func resizeReflowsColumns() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        var evaluations = 0
        let host = ViewHost(
            rootView: BodyProbe {
                evaluations += 1
                return LazyVGrid(columns: [GridItem(.adaptive(minimum: 3))], spacing: 0) {
                    Text("A")
                    Text("B")
                    Text("C")
                }
            }, runLoop: RecordingRunLoop(), output: output)

        // -- Act --
        try host.start(size: TerminalSize(columns: 9, rows: 5))
        try host.resize(to: TerminalSize(columns: 3, rows: 5))
        host.stop()

        // -- Assert --
        #expect(evaluations == 1)
        #expect(output.writes.count == 3)
        #expect(output.writes[0].contains("A  B  C"))
        #expect(output.writes[1].contains("A  "))
        #expect(output.writes[1].contains("B  "))
        #expect(output.writes[1].contains("C  "))
    }

    private struct BodyProbe<Content: View>: View {
        let makeContent: @MainActor () -> Content
        var body: some View { makeContent() }
    }
}

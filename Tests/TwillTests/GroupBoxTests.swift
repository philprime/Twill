import Foundation
import Testing

@testable import Twill

@Suite("Group box")
@MainActor
struct GroupBoxTests {
    @Test("The title interrupts the rounded top edge without covering content")
    func titledBox() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            GroupBox("Options") {
                Text("--help").frame(width: 14, alignment: .leading)
            })

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "╭─ Options ────╮\n│--help        │\n╰──────────────╯")
    }

    @Test("A title wider than the content contributes to the intrinsic width")
    func titleWidth() {
        // -- Arrange --
        let renderer = ViewRenderer.make(GroupBox("界面") { Text("A") })

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 9, height: 3))
        #expect(frame.grid?.snapshotText == "╭─ 界面 ╮\n│A      │\n╰───────╯")
    }

    @Test("Titles clip to the top edge and preserve both corners", arguments: [2, 3, 4, 5, 6])
    func clippedTitle(width: Int) {
        // -- Arrange --
        let renderer = ViewRenderer.make(GroupBox("界面") { Text("ABC") })
        let expected = [2: "╭╮", 3: "╭─╮", 4: "╭─ ╮", 5: "╭─ ─╮", 6: "╭─ 界╮"]

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: width, height: 3))

        // -- Assert --
        #expect(frame.grid?.snapshotText.split(separator: "\n").first.map(String.init) == expected[width])
    }

    @Test("Foreground modifiers style the title and border while preserving content overrides")
    func styling() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            GroupBox("Title", border: .double) {
                Text("Body").foregroundStyle(Color.blue)
            }
            .foregroundStyle(Color.red))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "╔═ Title ╗\n║Body    ║\n╚════════╝")
        #expect(frame.grid?.foreground(column: 0, row: 0) == Color.red)
        #expect(frame.grid?.foreground(column: 3, row: 0) == Color.red)
        #expect(frame.grid?.foreground(column: 1, row: 1) == Color.blue)
    }

    @Test("Group boxes inherit foreground styling from their container")
    func inheritedStyling() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack {
                GroupBox("Title") { Text("Body") }
            }
            .foregroundStyle(Color.green))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.foreground(column: 0, row: 0) == Color.green)
        #expect(frame.grid?.foreground(column: 3, row: 0) == Color.green)
        #expect(frame.grid?.foreground(column: 1, row: 1) == Color.green)
    }

    @Test("An empty title leaves an uninterrupted rounded border")
    func emptyTitle() {
        // -- Arrange --
        let renderer = ViewRenderer.make(GroupBox("") { Text("A") })

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "╭─╮\n│A│\n╰─╯")
    }
}

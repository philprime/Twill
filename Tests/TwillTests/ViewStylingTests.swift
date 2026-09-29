import Foundation
import Testing

@testable import Twill

@Suite("View styling")
@MainActor
struct ViewStylingTests {
    private let borderColor = Color(red: 92, green: 92, blue: 92)

    @Test("Borders enclose content and reserve cells in stack layout")
    func borderLayout() {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("Hi").border(.single, color: borderColor)
                Text("!")
            })

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 5, height: 3))
        #expect(frame.grid?.snapshotText == "┌──┐ \n│Hi│!\n└──┘ ")
    }

    @Test("Borders clip safely when the viewport is smaller than their content")
    func clippedBorder() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("Hello").border(.single, color: borderColor))

        // -- Act --
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 4, height: 3))

        // -- Assert --
        #expect(frame.grid?.snapshotText == "┌──┐\n│He│\n└──┘")
    }

    @Test("A border style colors its rings without replacing the content foreground")
    func styledBorder() {
        // -- Arrange --
        let blue = Color(red: 0, green: 180, blue: 240)
        let renderer = ViewRenderer.make(Text("A").foregroundStyle(blue).border(.single, color: AccentStyle()))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.foreground(column: 0, row: 0) == Color(red: 255, green: 102, blue: 0))
        #expect(frame.grid?.foreground(column: 1, row: 1) == blue)
    }

    @Test("Double borders use one cell per edge")
    func doubleBorder() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").border(.double, color: borderColor))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.size == CellSize(width: 3, height: 3))
        #expect(frame.grid?.snapshotText == "╔═╗\n║A║\n╚═╝")
        #expect(frame.grid?.foreground(column: 0, row: 0) == borderColor)
    }

    @Test("Rounded borders use curved corners")
    func roundedBorder() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").border(.rounded, color: borderColor))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "╭─╮\n│A│\n╰─╯")
    }

    @Test("Heavy borders use heavy box-drawing glyphs")
    func heavyBorder() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").border(.heavy, color: borderColor))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "┏━┓\n┃A┃\n┗━┛")
    }

    @Test("Dashed borders use dashed sides")
    func dashedBorder() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").border(.dashed, color: borderColor))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "┌┄┐\n┆A┆\n└┄┘")
    }

    @Test("Custom border glyphs draw every corner and edge")
    func customBorder() {
        // -- Arrange --
        let glyphs = Border.Glyphs(
            topLeft: "1", top: "2", topRight: "3", left: "4", right: "5",
            bottomLeft: "6", bottom: "7", bottomRight: "8")
        let renderer = ViewRenderer.make(Text("AB").border(.custom(glyphs), color: borderColor))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "1223\n4AB5\n6778")
    }

    @Test("Nested foreground and background styles inherit and override independently")
    func nestedStyles() {
        // -- Arrange --
        let orange = Color(red: 255, green: 102, blue: 0)
        let blue = Color(red: 0, green: 180, blue: 240)
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                Text("B").foregroundStyle(blue)
            }
            .foregroundStyle(orange)
            .backgroundStyle(blue))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.foreground(column: 0, row: 0) == orange)
        #expect(frame.grid?.foreground(column: 1, row: 0) == blue)
        #expect(frame.grid?.background(column: 0, row: 0) == blue)
        #expect(frame.grid?.background(column: 1, row: 0) == blue)
    }

    @Test("Foreground styles resolve through the Style contract")
    func customForegroundStyle() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").foregroundStyle(AccentStyle()))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.foreground(column: 0, row: 0) == Color(red: 255, green: 102, blue: 0))
    }

    private struct AccentStyle: Style {
        let color = Color(red: 255, green: 102, blue: 0)
    }

    @Test("Background styles resolve through the Style contract")
    func customBackgroundStyle() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("A").backgroundStyle(AccentStyle()))

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.background(column: 0, row: 0) == Color(red: 255, green: 102, blue: 0))
    }

    @Test("Background fills blank cells inside the view without bleeding into siblings")
    func backgroundFill() {
        // -- Arrange --
        let orange = Color(red: 255, green: 102, blue: 0)
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                VStack {
                    Text("AB")
                    Text("C")
                }.backgroundStyle(orange)
                Text("D")
            })

        // -- Act --
        let frame = renderer.render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "ABD\nC  ")
        #expect(frame.grid?.background(column: 1, row: 1) == orange)
        #expect(frame.grid?.background(column: 2, row: 1) == nil)
    }

    @Test("Style-only changes redraw cells and colored borders inherit their foreground")
    func styleOnlyChange() {
        // -- Arrange --
        let orange = Color(red: 255, green: 102, blue: 0)
        let plain = ViewRenderer.make(Text("A").border(.single, color: borderColor)).render(.now).grid!
        let colored = ViewRenderer.make(Text("A").border(.single, color: orange)).render(.now).grid!

        // -- Act --
        let output = InlineFrameEncoder.encode(colored, previous: plain)

        // -- Assert --
        #expect(colored.foreground(column: 0, row: 0) == orange)
        #expect(colored.foreground(column: 1, row: 1) == nil)
        #expect(output.contains("\u{1B}[38;2;255;102;0m"))
    }

    @Test("Color changes produce SGR output and restore defaults at the end of the run")
    func encodedColors() {
        // -- Arrange --
        let red = Color(red: 255, green: 0, blue: 0)
        let renderer = ViewRenderer.make(Text("X").foregroundStyle(red).backgroundStyle(red))
        let initial = renderer.render(.now).grid!
        let plain = ViewRenderer.make(Text("X")).render(.now).grid!

        // -- Act --
        let output = InlineFrameEncoder.encode(initial, previous: nil)
        let changed = InlineFrameEncoder.encode(plain, previous: initial)

        // -- Assert --
        #expect(output.contains("\u{1B}[38;2;255;0;0m"))
        #expect(output.contains("\u{1B}[48;2;255;0;0m"))
        #expect(output.hasSuffix("\u{1B}[39m\u{1B}[49m"))
        #expect(changed.contains("\rX"))
        #expect(InlineFrameEncoder.encode(initial, previous: initial).isEmpty)
    }
}

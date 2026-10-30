import Testing

@testable import Twill

@Suite("Text break and truncation modes")
@MainActor
struct TextBreakModeTests {
    @Test("Word, character and clipping policies have distinct behavior")
    func breakModes() throws {
        // -- Arrange --
        let word = ViewRenderer.make(Text("ab cd ef").lineBreakMode(.wordWrapping))
        let character = ViewRenderer.make(Text("ab cd ef").lineBreakMode(.characterWrapping))
        let clipped = ViewRenderer.make(Text("ab cd ef").lineBreakMode(.clipping))

        // -- Act --
        let wordFrame = try #require(word.render(.now, proposal: .init(width: 4)).grid)
        let characterFrame = try #require(character.render(.now, proposal: .init(width: 4)).grid)
        let clippedFrame = try #require(clipped.render(.now, proposal: .init(width: 4)).grid)

        // -- Assert --
        #expect(wordFrame.snapshotText == "ab\ncd\nef")
        #expect(characterFrame.snapshotText == "ab c\nd ef")
        #expect(clippedFrame.snapshotText == "ab c")
    }

    @Test("SwiftUI-style truncation modes preserve the chosen ends of omitted text")
    func truncationModes() throws {
        // -- Arrange --
        let tail = ViewRenderer.make(Text("abcdef").lineLimit(1))
        let head = ViewRenderer.make(Text("abcdef").lineLimit(1).truncationMode(.head))
        let middle = ViewRenderer.make(Text("abcdef").lineLimit(1).truncationMode(.middle))

        // -- Act --
        let tailFrame = try #require(tail.render(.now, proposal: .init(width: 4)).grid)
        let headFrame = try #require(head.render(.now, proposal: .init(width: 4)).grid)
        let middleFrame = try #require(middle.render(.now, proposal: .init(width: 4)).grid)

        // -- Assert --
        #expect(tailFrame.snapshotText == "abc…")
        #expect(headFrame.snapshotText == "…def")
        #expect(middleFrame.snapshotText == "ab…f")
    }

    @Test("Only the last visible line indicates omitted wrapped content")
    func multilineLimit() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("one two three four").lineLimit(2))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 5)).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 5, height: 2))
        #expect(frame.snapshotText == "one  \ntwo …")
    }

    @Test(
        "Omitting trailing empty lines preserves fitting text without an ellipsis",
        arguments: ["abc\n", "abc\r\n", "abc\n\n"],
        [Text.TruncationMode.tail, .head, .middle])
    func trailingEmptyLines(text: String, mode: Text.TruncationMode) throws {
        // -- Arrange --
        let lineLimited = ViewRenderer.make(Text(text).lineLimit(1).truncationMode(mode))
        let heightLimited = ViewRenderer.make(Text(text).truncationMode(mode))

        // -- Act --
        let lineFrame = try #require(lineLimited.render(.now, proposal: .init(width: 3)).grid)
        let heightFrame = try #require(heightLimited.render(.now, proposal: .init(width: 3, height: 1)).grid)

        // -- Assert --
        #expect(lineFrame.size == CellSize(width: 3, height: 1))
        #expect(lineFrame.snapshotText == "abc")
        #expect(heightFrame.size == CellSize(width: 3, height: 1))
        #expect(heightFrame.snapshotText == "abc")
    }

    @Test("Omitting nonempty logical lines indicates vertical overflow even when their joined text fits")
    func nonemptyOmittedLines() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("a\nb").lineLimit(1))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 10)).grid)

        // -- Assert --
        #expect(frame.size.height == 1)
        #expect(frame.snapshotText.contains("…"))
    }

    @Test("Wide glyphs never split around the ellipsis and narrow widths make progress")
    func wideTruncation() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("界界界").lineLimit(1).truncationMode(.middle))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 4)).grid)
        let narrow = try #require(renderer.render(.now, proposal: .init(width: 1)).grid)

        // -- Assert --
        #expect(frame.size == CellSize(width: 4, height: 1))
        #expect(frame[0, 0] == .glyph("界", width: 2))
        #expect(frame[1, 0] == .continuation)
        #expect(frame[2, 0] == .glyph("…", width: 1))
        #expect(frame[3, 0] == .blank)
        #expect(narrow.snapshotText == "…")
    }

    @Test("Modifiers inherit through containers while nearer text overrides them")
    func inheritedModes() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Text("ab cd")
                Text("ab cd").lineBreakMode(.characterWrapping)
            }.lineBreakMode(.clipping))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 3)).grid)

        // -- Assert --
        #expect(frame.snapshotText == "ab \nab \ncd ")
    }

    @Test("Nil resets an inherited line limit and zero limits use one line")
    func limitReset() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Text("abcdef")
                Text("abcdef").lineLimit(nil)
            }.lineLimit(0))

        // -- Act --
        let frame = try #require(renderer.render(.now, proposal: .init(width: 3)).grid)

        // -- Assert --
        #expect(frame.snapshotText == "ab…\nabc\ndef")
    }

    @Test("Modifiers can follow frames and explicit truncation applies to height constraints")
    func modifierOrder() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Text("abcdef").frame(width: 4, height: 1).truncationMode(.head))

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "…def")
    }

    @Test("Unconstrained text and content that fits never gain an ellipsis")
    func noOverflow() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("界e\u{301}").lineLimit(1).truncationMode(.middle))

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)
        let empty = renderer.render(.now, proposal: .init(width: 0)).grid

        // -- Assert --
        #expect(frame.snapshotText == "界e\u{301}")
        #expect(empty?.size == .zero)
    }
}

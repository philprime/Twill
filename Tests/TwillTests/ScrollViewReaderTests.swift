import Foundation
import Testing

@testable import Twill

@Suite("Programmatic pane scrolling")
@MainActor
struct ScrollViewReaderTests {
    @Test("A reader scrolls to keyed rows at the requested viewport anchor")
    func readerScrollsToKeyedRows() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            ScrollViewReader { reader in
                ScrollView {
                    VStack {
                        ForEach(0..<5, id: \.self) { index in Text("Row \(index)") }
                    }
                }
                .frame(height: 2)
                .onKeyPress { key in
                    switch key {
                    case .G: reader.scrollTo(4, anchor: .bottom)
                    case .g: reader.scrollTo(0, anchor: .top)
                    default: return .ignored
                    }
                    return .handled
                }
            })
        let first = try #require(renderer.render(.now).grid)

        // -- Act --
        let jumpedToBottom = renderer.handle(.G)
        let bottom = try #require(renderer.drawFrame(proposal: .unspecified))
        let jumpedToTop = renderer.handle(.g)
        let top = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(jumpedToBottom)
        #expect(jumpedToTop)
        #expect(first.snapshotText.contains("Row 0"))
        #expect(bottom.snapshotText.contains("Row 4"))
        #expect(!bottom.snapshotText.contains("Row 0"))
        #expect(top.snapshotText.contains("Row 0"))
    }

    @Test("Page keys scroll a pane with buttons without activating or moving focus")
    func pageKeysWithButtons() throws {
        // -- Arrange --
        var activated: [Int] = []
        let renderer = ViewRenderer.make(
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(0..<5, id: \.self) { index in
                        Button("Row \(index)") { activated.append(index) }
                    }
                }
            }.frame(height: 2))
        _ = renderer.render(.now)

        // -- Act --
        let down = renderer.handle(.pageDown)
        let middle = try #require(renderer.drawFrame(proposal: .unspecified))
        _ = renderer.handle(.enter)
        let pagedUp = renderer.handle(.pageUp)
        let top = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(down && pagedUp)
        #expect(middle.snapshotText == "Row 2\nRow 3")
        #expect(activated == [0])
        #expect(top.snapshotText == "Row 0\nRow 1")
        #expect(top.isFocused(column: 0, row: 0))
    }

    @Test("Button keys bubble to reader shortcuts and explicit scrolling persists until focus moves")
    func readerScrollsPastFocusedButton() throws {
        // -- Arrange --
        var activated: [Int] = []
        let renderer = ViewRenderer.make(
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(0..<5, id: \.self) { index in
                            Button("Row \(index)") { activated.append(index) }
                        }
                    }
                }
                .frame(height: 2)
                .onKeyPress { key in
                    switch key {
                    case .G: reader.scrollTo(4, anchor: .bottom)
                    case .g: reader.scrollTo(0, anchor: .top)
                    default: return .ignored
                    }
                    return .handled
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        let jumped = renderer.handle(.G)
        let bottom = try #require(renderer.drawFrame(proposal: .unspecified))
        let redrawn = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        let moved = renderer.handle(.arrowDown)
        let revealed = try #require(renderer.drawFrame(proposal: .unspecified))
        _ = renderer.handle(.G)
        _ = renderer.drawFrame(proposal: .unspecified)
        let returned = renderer.handle(.g)
        let top = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(jumped && moved && returned)
        #expect(bottom.snapshotText == "Row 3\nRow 4")
        #expect(redrawn.snapshotText == "Row 3\nRow 4")
        #expect(activated == [0])
        #expect(revealed.snapshotText == "Row 1\nRow 2")
        #expect(revealed.isFocused(column: 0, row: 0))
        #expect(top.snapshotText == "Row 0\nRow 1")
    }

}

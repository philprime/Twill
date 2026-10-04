import Foundation
import Testing

@testable import Twill

@Suite("Scrollable panes")
@MainActor
struct ScrollViewTests {
    @Test("Moving focus below the viewport reveals the focused row")
    func revealsOffscreenFocus() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            ScrollView {
                VStack {
                    Text("One").focusable()
                    Text("Two").focusable()
                    Text("Three").focusable()
                }
            }.frame(height: 2))
        let first = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.arrowDown)
        let last = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(
            first.snapshotText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) } == ["One", "Two"])
        #expect(
            last.snapshotText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) } == [
                "Two", "Three",
            ])
        #expect(last.isFocused(column: 0, row: 1))
        #expect(!renderer.handle(.arrowDown))
    }

    @Test("A viewer without controls receives focus and scrolls without Enter")
    func viewerScrolls() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            ScrollView {
                VStack {
                    Text("One")
                    Text("Two")
                    Text("Three")
                    Text("Four")
                }
            }.frame(height: 2))
        _ = renderer.render(.now)

        // -- Act --
        let moved = renderer.handle(.arrowDown)
        let frame = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(moved)
        #expect(
            frame.snapshotText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) } == [
                "Two", "Three",
            ])
        #expect(!renderer.handle(.enter))
    }

    @Test("A bordered grid scrolls and does not highlight its entire content")
    func borderedGrid() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack {
                Text("Header")
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                        ForEach(0..<30, id: \.self) { index in Text("Item\(index)") }
                    }
                }
                .border(.single, color: Color.white)
            })
        let proposal = ProposedCellSize(width: 48, height: 6)
        let initial = try #require(renderer.render(.now, proposal: proposal).grid)

        // -- Act --
        let moved = renderer.handle(.pageDown)
        let scrolled = try #require(renderer.drawFrame(proposal: proposal))

        // -- Assert --
        #expect(moved)
        #expect(initial.snapshotText.contains("Item0"))
        #expect(scrolled.snapshotText.contains("Item6"))
        let highlighted = initial.isFocused(column: 1, row: 2)
        #expect(!highlighted)
    }

    @Test("Page keys move a viewer by a viewport and stop at content edges")
    func pageScroll() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            ScrollView {
                VStack {
                    Text("1")
                    Text("2")
                    Text("3")
                    Text("4")
                    Text("5")
                }
            }.frame(height: 2))
        _ = renderer.render(.now)

        // -- Act --
        let down = renderer.handle(.pageDown)
        let middle = try #require(renderer.drawFrame(proposal: .unspecified))
        _ = renderer.handle(.pageDown)
        let end = try #require(renderer.drawFrame(proposal: .unspecified))
        let stopped = renderer.handle(.pageDown)
        _ = renderer.handle(.pageUp)
        let back = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(down && !stopped)
        #expect(middle.snapshotText == "3\n4")
        #expect(end.snapshotText == "4\n5")
        #expect(back.snapshotText == "2\n3")
    }

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
                    case .character("G"): reader.scrollTo(4, anchor: .bottom)
                    case .character("g"): reader.scrollTo(0, anchor: .top)
                    default: return .ignored
                    }
                    return .handled
                }
            })
        let first = try #require(renderer.render(.now).grid)

        // -- Act --
        let jumpedToBottom = renderer.handle(.character("G"))
        let bottom = try #require(renderer.drawFrame(proposal: .unspecified))
        let jumpedToTop = renderer.handle(.character("g"))
        let top = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(jumpedToBottom)
        #expect(jumpedToTop)
        #expect(first.snapshotText.contains("Row 0"))
        #expect(bottom.snapshotText.contains("Row 4"))
        #expect(!bottom.snapshotText.contains("Row 0"))
        #expect(top.snapshotText.contains("Row 0"))
    }

    @Test("Tab confines arrows to each pane and restores its focus and offset")
    func paneRestoration() throws {
        // -- Arrange --
        var activated: [String] = []
        let renderer = ViewRenderer.make(
            HStack(spacing: 1) {
                ScrollView {
                    VStack {
                        Text("A1").focusable().onKeyPress { key in
                            guard key == .enter else { return .ignored }
                            activated.append("A1")
                            return .handled
                        }
                        Text("A2").focusable().onKeyPress { key in
                            guard key == .enter else { return .ignored }
                            activated.append("A2")
                            return .handled
                        }
                    }
                }.frame(height: 1)
                ScrollView {
                    VStack {
                        Text("B1").focusable().onKeyPress { key in
                            guard key == .enter else { return .ignored }
                            activated.append("B1")
                            return .handled
                        }
                        Text("B2").focusable().onKeyPress { key in
                            guard key == .enter else { return .ignored }
                            activated.append("B2")
                            return .handled
                        }
                    }
                }.frame(height: 1)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        let boundary = renderer.handle(.arrowDown)
        let switched = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        let returned = renderer.handle(.shiftTab)
        let frame = try #require(renderer.drawFrame(proposal: .unspecified))
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(!boundary)
        #expect(switched && returned)
        #expect(activated == ["A2", "B1", "B2", "A2"])
        #expect(frame.snapshotText == "A2 B2")
        #expect(frame.isFocused(column: 0, row: 0))
    }

    @Test("Editing a text field keeps arrows and Tab in the field")
    func editingStaysInPane() {
        // -- Arrange --
        let text = Binding<String>(get: { "Hi" }, set: { _ in })
        let renderer = ViewRenderer.make(
            HStack {
                ScrollView { TextField("Name", text: text) }.frame(height: 1)
                ScrollView { Text("Other").focusable() }.frame(height: 1)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        let tab = renderer.handle(.tab)
        let arrow = renderer.handle(.arrowRight)
        renderer.refreshContent(at: .now)
        let frame = renderer.drawFrame(proposal: .unspecified)

        // -- Assert --
        #expect(tab && arrow)
        #expect(frame?.isFocused(column: 0, row: 0) == true)
        #expect(renderer.caretPosition != nil)
    }
}

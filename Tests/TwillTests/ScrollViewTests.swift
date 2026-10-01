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

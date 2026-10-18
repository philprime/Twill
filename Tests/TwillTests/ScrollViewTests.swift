import Foundation
import Testing

@testable import Twill

@Suite("Scrollable panes")
@MainActor
struct ScrollViewTests {
    @Test("Parent refresh retains manual scroll position and keyed replacement resets it")
    func mountedScrollLifetime() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { context in
                ForEach(context.date < start.addingTimeInterval(2) ? [0] : [1], id: \.self) { _ in
                    ScrollView {
                        VStack {
                            Text("0")
                            Text("1")
                            Text("2")
                            Text("3")
                        }
                    }.frame(height: 2)
                }
            })
        let initial = try #require(renderer.render(start).grid)
        weak var originalPane: ViewRenderer?
        originalPane = renderer.focusTarget()

        // -- Act --
        let handled = renderer.handle(.arrowDown)
        let scrolled = try #require(renderer.render(start).grid)
        let refreshed = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        let retainedPane = originalPane != nil
        let replaced = try #require(renderer.render(start.addingTimeInterval(2)).grid)

        // -- Assert --
        #expect(handled)
        #expect(initial.snapshotText == "0\n1")
        #expect(scrolled.snapshotText == "1\n2")
        #expect(refreshed == scrolled)
        #expect(replaced == initial)
        #expect(retainedPane)
        #expect(originalPane == nil)
    }

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
                }.frame(height: 1).keyboardPane()
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
                }.frame(height: 1).keyboardPane()
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

    @Test("Tab leaves a search field and reverse traversal restores pane focus and scrolling")
    func textFieldPaneTraversal() throws {
        // -- Arrange --
        var text = "ab"
        var activated: [String] = []
        let renderer = ViewRenderer.make(
            PaneTraversalFixture(
                text: Binding(get: { text }, set: { text = $0 }), onActivate: { activated.append($0) }))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowLeft)
        _ = renderer.render(.now)
        _ = renderer.handle(.x)
        _ = renderer.render(.now)
        let leftSearch = renderer.handle(.tab)
        let listFrame = try #require(renderer.render(.now).grid)
        let listCaret = renderer.caretPosition
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        let enteredPreview = renderer.handle(.tab)
        _ = renderer.handle(.arrowDown)
        let previewFrame = try #require(renderer.render(.now).grid)
        let returnedToList = renderer.handle(.shiftTab)
        let restoredList = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        let returnedToSearch = renderer.handle(.shiftTab)
        _ = renderer.render(.now)
        let searchCaret = renderer.caretPosition
        _ = renderer.handle(.c)
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.tab)
        let restoredPreview = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(leftSearch && enteredPreview && returnedToList && returnedToSearch)
        #expect(listFrame.isFocused(column: 14, row: 1))
        #expect(listCaret == nil)
        #expect(previewFrame.snapshotText.contains("Second"))
        #expect(restoredList.isFocused(column: 14, row: 1))
        #expect(restoredList.snapshotText.contains("Two"))
        #expect(activated == ["Two"])
        #expect(searchCaret != nil)
        #expect(text == "axbc")
        #expect(restoredPreview.snapshotText.contains("Second"))
    }
}

@MainActor
private struct PaneTraversalFixture: View {
    let text: Binding<String>
    let onActivate: @MainActor (String) -> Void

    var body: some View {
        HStack(spacing: 1) {
            GroupBox("Search") {
                ScrollView {
                    TextField("Search", text: text)
                }.frame(width: 8, height: 1).keyboardPane()
            }
            GroupBox("Notes") {
                ScrollView {
                    VStack {
                        Button("One") { onActivate("One") }
                        Button("Two") { onActivate("Two") }
                    }
                }.frame(width: 6, height: 1).keyboardPane()
            }
            GroupBox("Preview") {
                ScrollView {
                    VStack {
                        Text("First")
                        Text("Second")
                    }
                }.frame(width: 8, height: 1).keyboardPane()
            }
        }
    }
}

import Foundation
import Testing

@testable import Twill

@Suite("Independent keyboard panes")
@MainActor
struct KeyboardPaneTests {
    @Test("Non-scrolling panes confine arrows and restore their remembered controls")
    func nonScrollingPanes() {
        // -- Arrange --
        var activated: [String] = []
        let renderer = ViewRenderer.make(
            HStack {
                KeyboardPane {
                    VStack {
                        Button("A1") { activated.append("A1") }
                        Button("A2") { activated.append("A2") }
                    }
                }
                VStack {
                    Button("B1") { activated.append("B1") }
                    Button("B2") { activated.append("B2") }
                }.keyboardPane()
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        let boundary = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        let switched = renderer.handle(.tab)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        let returned = renderer.handle(.shiftTab)
        _ = renderer.handle(.enter)
        let beforeFirst = renderer.handle(.shiftTab)

        // -- Assert --
        #expect(!boundary && !beforeFirst)
        #expect(switched && returned)
        #expect(activated == ["A2", "B2", "A2"])
    }

    @Test("Plain scrolling viewports do not create keyboard traversal boundaries")
    func plainScrollViews() {
        // -- Arrange --
        var activated: [String] = []
        let renderer = ViewRenderer.make(
            HStack {
                ScrollView {
                    Button("A") { activated.append("A") }
                }
                ScrollView {
                    Button("B") { activated.append("B") }
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        let moved = renderer.handle(.arrowRight)
        _ = renderer.handle(.enter)
        let tab = renderer.handle(.tab)

        // -- Assert --
        #expect(moved)
        #expect(!tab)
        #expect(activated == ["B"])
    }

    @Test("Plain viewport navigation resumes focus reveal after manual scrolling")
    func plainViewportReveal() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            ScrollView {
                VStack {
                    Button("A") {}
                    Button("B") {}
                    Button("C") {}
                    Button("D") {}
                }
            }.frame(height: 2))
        _ = renderer.render(.now)
        _ = renderer.handle(.pageDown)
        let manual = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        let revealed = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(manual.snapshotText == "C\nD")
        #expect(revealed.snapshotText == "B\nC")
        #expect(revealed.isFocused(column: 0, row: 0))
    }

    @Test("A pane can group multiple viewports without sharing their offsets")
    func multipleViewports() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            KeyboardPane {
                HStack {
                    ScrollView {
                        VStack {
                            Button("A0") {}
                            Button("A1") {}
                            Button("A2") {}
                        }
                    }.frame(height: 1)
                    ScrollView {
                        VStack {
                            Button("B0") {}
                            Button("B1") {}
                            Button("B2") {}
                        }
                    }.frame(height: 1)
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        let paged = renderer.handle(.pageDown)
        let manual = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.arrowDown)
        let moved = renderer.handle(.arrowDown)
        let crossed = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.pageDown)
        let independent = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(paged && moved)
        #expect(manual.snapshotText == "A1 B0")
        #expect(crossed.snapshotText == "A2 B0")
        #expect(crossed.isFocused(column: 3, row: 0))
        #expect(independent.snapshotText == "A2 B1")
    }

    @Test("An outer pane groups default control panes rather than adding Tab stops")
    func groupedDefaultPanes() {
        // -- Arrange --
        var selected: Int?
        var activated = false
        let renderer = ViewRenderer.make(
            HStack {
                KeyboardPane {
                    VStack {
                        List([1, 2], id: \.self, selection: Binding(get: { selected }, set: { selected = $0 })) {
                            Text("\($0)")
                        }
                        Button("Grouped") { activated = true }
                    }
                }
                Button("Outside") {}.keyboardPane()
            })
        _ = renderer.render(.now)

        // -- Act --
        let movedWithinGroup = renderer.handle(.arrowRight)
        _ = renderer.handle(.enter)
        let switched = renderer.handle(.tab)
        let stopped = renderer.handle(.tab)

        // -- Assert --
        #expect(movedWithinGroup && activated)
        #expect(switched && !stopped)
    }

    @Test("Static keyboard panes remain idle and do not highlight all their content")
    func staticPane() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("Static").keyboardPane())

        // -- Act --
        let frame = renderer.render(.now)
        let grid = try #require(frame.grid)

        // -- Assert --
        #expect(frame.nextUpdate == nil)
        #expect(grid.snapshotText == "Static")
        #expect(!grid.isFocused(column: 0, row: 0))
    }
}

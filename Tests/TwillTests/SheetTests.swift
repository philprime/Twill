import Foundation
import Testing

@testable import Twill

@Suite("Modal sheets")
@MainActor
struct SheetTests {
    @Test("Centered overlay retains the underlying page and traps focus in the sheet")
    func centeredOverlay() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Text("Notes").focusable().sheet(isPresented: Binding(get: { true }, set: { _ in })) {
                Text("Help").focusable()
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: ProposedCellSize(width: 20, height: 7)).grid)

        // -- Assert --
        #expect(grid.size == CellSize(width: 20, height: 7))
        #expect(grid[0, 0] == .glyph("N", width: 1))
        #expect(grid[8, 3] == .glyph("H", width: 1))
        #expect(grid.isFocused(column: 8, row: 3))
        #expect(!grid.isFocused(column: 0, row: 0))
    }

    @Test("Consecutive input keys use the new modal scope before presentation")
    func consecutiveInput() throws {
        // -- Arrange --
        var baseEvents: [String] = []
        var sheetKeys: [KeyEvent] = []
        let runLoop = RecordingRunLoop()
        let host = ViewHost(
            rootView: SheetFixture(onBase: { baseEvents.append($0) }, onSheet: { sheetKeys.append($0) }),
            runLoop: runLoop, output: RecordingTerminalOutput()
        )
        try host.start()

        // -- Act --
        _ = host.handle(.arrowRight)
        _ = host.handle(.character("o"))
        let trapped = host.handle(.character("x"))
        _ = host.handle(.escape)
        let restored = host.handle(.enter)
        host.stop()

        // -- Assert --
        #expect(trapped)
        #expect(restored)
        #expect(sheetKeys == [.character("x"), .escape])
        #expect(baseEvents == ["B"])
    }

    @Test("A sheet without focus targets still traps ignored keys")
    func unfocusableSheet() throws {
        // -- Arrange --
        var leaked = false
        let renderer = ViewRenderer.make(HelpSheetFixture(onLeak: { leaked = true }))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.character("o"))
        let sheet = try #require(renderer.render(.now).grid)
        let trapped = renderer.handle(.character("x"))
        _ = renderer.handle(.escape)
        let base = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(sheet.snapshotText == "Help")
        #expect(!sheet.isFocused(column: 0, row: 0))
        #expect(trapped)
        #expect(!leaked)
        #expect(base.snapshotText == "Base")
        #expect(base.isFocused(column: 0, row: 0))
    }

    @Test("Nested sheets restore the enclosing modal focus before the base focus")
    func nestedSheets() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(NestedSheetFixture())
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.character("o"))
        let outer = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.character("n"))
        let inner = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.escape)
        let restoredOuter = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.escape)
        let restoredBase = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(outer.snapshotText == "Outer")
        #expect(outer.isFocused(column: 0, row: 0))
        #expect(inner.snapshotText == "Inner")
        #expect(inner.isFocused(column: 0, row: 0))
        #expect(restoredOuter.snapshotText == "Outer")
        #expect(restoredOuter.isFocused(column: 0, row: 0))
        #expect(restoredBase.snapshotText == "Base")
        #expect(restoredBase.isFocused(column: 0, row: 0))
    }

    @Test("The base timeline continues updating beneath a sheet without restarting its deadline")
    func hiddenTimeline() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var now = start
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: ChangingBaseSheetFixture(start: start, onActivate: { _ in }),
            runLoop: runLoop, output: output, now: { now }
        )
        try host.start()
        let deadline = try #require(runLoop.timers.first)

        // -- Act --
        _ = host.handle(.character("o"))
        try #require(runLoop.timers.last).action()
        let writesBeforeDeadline = output.writes.count
        now = start.addingTimeInterval(1)
        deadline.action()
        let writesAfterDeadline = output.writes.count
        _ = host.handle(.escape)
        try #require(runLoop.timers.last).action()

        // -- Assert --
        #expect(writesAfterDeadline == writesBeforeDeadline + 1)
        #expect(runLoop.cancelled.isEmpty)
        #expect(runLoop.timers.count == 4)
        #expect(output.writes.count == writesAfterDeadline + 1)
        host.stop()
    }

    @Test("Removing the saved base control while presented falls back to the first control")
    func removedBaseFocus() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var activated: [String] = []
        let renderer = ViewRenderer.make(ChangingBaseSheetFixture(start: start, onActivate: { activated.append($0) }))
        _ = renderer.render(start)

        // -- Act --
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.character("o"))
        let sheet = try #require(renderer.render(start).grid)
        let stillPresented = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        _ = renderer.handle(.escape)
        let base = try #require(renderer.render(start.addingTimeInterval(1)).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(sheet.snapshotText == "FirSheetcond")
        #expect(stillPresented.snapshotText == "Sheet")
        #expect(base.snapshotText == "First")
        #expect(base.isFocused(column: 0, row: 0))
        #expect(activated == ["First"])
    }

    @Test("A sheet traps keys and restores the previously focused control")
    func focusRestoration() throws {
        // -- Arrange --
        var baseEvents: [String] = []
        var sheetKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            SheetFixture(onBase: { baseEvents.append($0) }, onSheet: { sheetKeys.append($0) }))
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.character("o"))
        let sheet = try #require(renderer.render(.now).grid)
        let ignoredKeyTrapped = renderer.handle(.character("x"))
        _ = renderer.handle(.escape)
        let restored = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(initial.snapshotText == "A B")
        #expect(initial.isFocused(column: 0, row: 0))
        #expect(sheet.snapshotText == "Sheet")
        #expect(sheet.isFocused(column: 0, row: 0))
        #expect(ignoredKeyTrapped)
        #expect(restored.snapshotText == "A B")
        #expect(restored.isFocused(column: 2, row: 0))
        #expect(baseEvents == ["A", "B"])
        #expect(sheetKeys == [.character("x"), .escape])
    }
}

@MainActor
private struct NestedSheetFixture: View {
    @State private var outerPresented = false
    @State private var innerPresented = false

    var body: some View {
        Text("Base").focusable().onKeyPress { key in
            guard key == .character("o") else { return .ignored }
            outerPresented = true
            return .handled
        }
        .sheet(isPresented: $outerPresented) {
            Text("Outer").focusable().onKeyPress { key in
                if key == .character("n") {
                    innerPresented = true
                    return .handled
                }
                guard key == .escape else { return .ignored }
                outerPresented = false
                return .handled
            }
            .sheet(isPresented: $innerPresented) {
                Text("Inner").focusable().onKeyPress { key in
                    guard key == .escape else { return .ignored }
                    innerPresented = false
                    return .handled
                }
            }
        }
    }
}

@MainActor
private struct ChangingBaseSheetFixture: View {
    @State private var presented = false
    let start: Date
    let onActivate: @MainActor (String) -> Void

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            HStack(spacing: 1) {
                Text("First").focusable().onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    onActivate("First")
                    return .handled
                }
                if context.date == start { Text("Second").focusable() }
            }
        }
        .onKeyPress { key in
            guard key == .character("o") else { return .ignored }
            presented = true
            return .handled
        }
        .sheet(isPresented: $presented) {
            Text("Sheet").focusable().onKeyPress { key in
                guard key == .escape else { return .ignored }
                presented = false
                return .handled
            }
        }
    }
}

@MainActor
private struct HelpSheetFixture: View {
    @State private var presented = false
    let onLeak: @MainActor () -> Void

    var body: some View {
        Text("Base").focusable()
            .onKeyPress { key in
                guard key == .character("o") else { return .ignored }
                presented = true
                return .handled
            }
            .onKeyPress { key in
                guard key == .character("x") else { return .ignored }
                onLeak()
                return .handled
            }
            .sheet(isPresented: $presented) {
                Text("Help").onKeyPress { key in
                    guard key == .escape else { return .ignored }
                    presented = false
                    return .handled
                }
            }
    }
}

@MainActor
private struct SheetFixture: View {
    @State private var presented = false
    let onBase: @MainActor (String) -> Void
    let onSheet: @MainActor (KeyEvent) -> Void

    var body: some View {
        HStack(spacing: 1) {
            Text("A").focusable().onKeyPress { key in
                guard key == .enter else { return .ignored }
                onBase("A")
                return .handled
            }
            Text("B").focusable().onKeyPress { key in
                if key == .character("o") {
                    presented = true
                    return .handled
                }
                guard key == .enter else { return .ignored }
                onBase("B")
                return .handled
            }
        }
        .onKeyPress { key in
            guard key == .character("x") else { return .ignored }
            onBase("parent")
            return .handled
        }
        .sheet(isPresented: $presented) {
            Text("Sheet").focusable().onKeyPress { key in
                onSheet(key)
                if key == .escape {
                    presented = false
                    return .handled
                }
                return .ignored
            }
        }
    }
}

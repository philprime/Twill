import Testing

@testable import Twill

@Suite("Empty state and status composition")
@MainActor
struct EmptyStateStatusTests {
    @Test("Unavailable content centers its intrinsic label and description in offered space")
    func centeredState() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(ContentUnavailableView("Empty", description: "Try again"))

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 15, height: 7)).grid)

        // -- Assert --
        #expect(grid.size == CellSize(width: 15, height: 7))
        #expect(grid[5, 2] == .glyph("E", width: 1))
        #expect(grid[3, 4] == .glyph("T", width: 1))
        #expect(grid.attributes(column: 5, row: 2).contains(.bold))
    }

    @Test("Custom description appearance overrides the component default and static content stays idle")
    func customAppearance() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            ContentUnavailableView {
                Text("Top")
            } description: {
                Text("Red").foregroundStyle(Color.red)
            })

        // -- Act --
        let frame = renderer.render(.now)
        let grid = try #require(frame.grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 2) == .red)
        #expect(frame.nextUpdate == nil)
    }

    @Test("Title-only content stays intrinsic without an offer and accepts zero dimensions")
    func intrinsicAndZero() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(ContentUnavailableView("Empty"))

        // -- Act --
        let natural = try #require(renderer.render(.now).grid)
        let zero = try #require(renderer.drawFrame(proposal: .init(width: 0, height: 0)))

        // -- Assert --
        #expect(natural.snapshotText == "Empty")
        #expect(zero.size == .zero)
    }

    @Test("Custom labels, descriptions and actions retain concrete types and ordinary control behavior")
    func customContent() throws {
        // -- Arrange --
        var retries = 0
        let view: ContentUnavailableView<Text, Text, Button<Text>> = ContentUnavailableView(
            label: { return Text("Empty") }, description: { return Text("Retry") },
            actions: { return Button("Again") { retries += 1 } })
        let renderer = ViewRenderer.make(view)
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(initial.snapshotText.contains("Again"))
        #expect(retries == 1)
    }

    @Test("Key hints compose with status and flexible spacing without registering actions")
    func statusHints() throws {
        // -- Arrange --
        var actions = 0
        let command = Command("save", title: "Save", shortcuts: [KeyboardShortcut(.s)]) { actions += 1 }
        let renderer = ViewRenderer.make(
            StatusBar {
                Text("Ready")
                Spacer()
                KeyHints([command])
            })

        // -- Act --
        let grid = try #require(renderer.render(.now, proposal: .init(width: 20, height: 5)).grid)
        let handled = renderer.handle(.s)

        // -- Assert --
        #expect(grid.size == CellSize(width: 20, height: 1))
        #expect(grid.snapshotText == "Ready        s: Save")
        #expect(!handled && actions == 0)
    }

    @Test("Status bars clip multiline content to one row and narrow proposals safely")
    func statusClipping() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(StatusBar { Text("ABCDE\nFGHIJ") })

        // -- Act --
        let natural = try #require(renderer.render(.now).grid)
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 3)))

        // -- Assert --
        #expect(natural.snapshotText == "ABCDE")
        #expect(narrow.snapshotText == "ABC")
    }

    private struct Retry: View {
        @State private var attempts = 0
        var body: some View { Button("Retry \(attempts)") { attempts += 1 } }
    }

    @Test("Parent updates retain action state and Tab reaches ordinary status controls")
    func retainedActions() throws {
        // -- Arrange --
        var help = 0
        func content(_ message: String) -> some View {
            VStack {
                ContentUnavailableView {
                    Text("Unavailable")
                } description: {
                    Text(message)
                } actions: {
                    Retry()
                }
                StatusBar { Button("Help") { help += 1 } }
            }
        }
        let renderer = ViewRenderer.make(content("Original"))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content("Updated"), at: .now)
        let changed = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(changed.snapshotText.contains("Retry 1") && changed.snapshotText.contains("Updated"))
        #expect(help == 1)
    }

    private struct Counted: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return VStack {
                ContentUnavailableView("Empty", description: "Try again")
                StatusBar { Text("Ready") }
            }
        }
    }

    @Test("Cached resize repositions unavailable content and preserves the status row")
    func cachedResize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(Counted(evaluated: { evaluations += 1 }))
        _ = renderer.render(.now, proposal: .init(width: 15, height: 8))

        // -- Act --
        let resized = try #require(renderer.drawFrame(proposal: .init(width: 21, height: 10)))

        // -- Assert --
        #expect(resized.size == CellSize(width: 21, height: 10))
        #expect(resized.snapshotText.split(separator: "\n").last?.hasPrefix("Ready") == true)
        #expect(evaluations == 1)
    }

    @Test("Inherited disabled state excludes empty-state actions without unmounting them")
    func disabledActions() {
        // -- Arrange --
        var actions = 0
        let renderer = ViewRenderer.make(
            ContentUnavailableView {
                Text("Unavailable")
            } description: {
                Text("Retry later")
            } actions: {
                Button("Retry") { actions += 1 }
            }.disabled(true))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(actions == 0)
    }
}

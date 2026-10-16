import Testing

@testable import Twill

@Suite("Picker interaction")
@MainActor
struct PickerTests {
    private enum Sort: String, CaseIterable {
        case name = "Name"
        case date = "Date"
        case size = "Size"
    }

    private struct Fixture: View {
        @State var selection: Sort
        @State var options = Sort.allCases
        let capture: (Binding<Sort>, Binding<[Sort]>) -> Void

        var body: some View {
            capture($selection, $options)
            return VStack(alignment: .leading) {
                Picker("Sort", selection: $selection, options: options) { option in
                    Text(option.rawValue)
                }
                Button("Done") {}
            }
        }
    }

    @Test("Left and Right update mounted selection and redraw its marker")
    func keyboardSelection() throws {
        // -- Arrange --
        var selection: Binding<Sort>?
        let renderer = ViewRenderer.make(
            Fixture(selection: .name) {
                selection = $0
                _ = $1
            })
        _ = renderer.render(.now)

        // -- Act --
        let right = renderer.handle(.arrowRight)
        let next = try #require(renderer.render(.now).grid)
        let nextValue = selection?.wrappedValue
        let left = renderer.handle(.arrowLeft)
        let previous = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(right && left)
        #expect(next.snapshotText.hasPrefix("Sort: [ ] Name [x] Date [ ] Size\n"))
        #expect(nextValue == .date)
        #expect(previous.snapshotText.hasPrefix("Sort: [x] Name [ ] Date [ ] Size\n"))
        #expect(selection?.wrappedValue == .name)
    }

    @Test("Selection remains visible when focus moves away and is restored on return")
    func selectionAndFocus() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Fixture(selection: .date) { _, _ in })
        let focused = try #require(renderer.render(.now).grid)

        // -- Act --
        let moved = renderer.handle(.arrowDown)
        let blurred = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowUp)
        let restored = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(moved)
        #expect(focused.isFocused(column: 0, row: 0))
        #expect(!blurred.isFocused(column: 0, row: 0))
        #expect(blurred.isFocused(column: 0, row: 1))
        #expect(blurred.snapshotText.hasPrefix("Sort: [ ] Name [x] Date [ ] Size\n"))
        #expect(restored.isFocused(column: 0, row: 0))
        #expect(restored.snapshotText == focused.snapshotText)
    }

    @Test("Arrows clamp at the first and last option without rewriting selection")
    func boundaries() {
        // -- Arrange --
        var selection = Sort.name
        var writes = 0
        let renderer = ViewRenderer.make(
            Picker(
                "Sort",
                selection: Binding(
                    get: { selection },
                    set: {
                        selection = $0
                        writes += 1
                    }),
                options: Sort.allCases
            ) { Text($0.rawValue) })
        _ = renderer.render(.now)

        // -- Act --
        let first = renderer.handle(.arrowLeft)
        selection = .size
        let last = renderer.handle(.arrowRight)

        // -- Assert --
        #expect(first && last)
        #expect(selection == .size)
        #expect(writes == 0)
    }

    @Test("Removing the selected option displays a fallback without changing stored selection")
    func absentSelection() throws {
        // -- Arrange --
        var selection: Binding<Sort>?
        var options: Binding<[Sort]>?
        let renderer = ViewRenderer.make(
            Fixture(selection: .size) {
                selection = $0
                options = $1
            })
        _ = renderer.render(.now)

        // -- Act --
        options?.wrappedValue = [.name, .date]
        let fallback = try #require(renderer.render(.now).grid)
        let stored = selection?.wrappedValue
        _ = renderer.handle(.arrowRight)
        let updated = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(fallback.snapshotText.hasPrefix("Sort: [x] Name [ ] Date\n"))
        #expect(stored == .size)
        #expect(selection?.wrappedValue == .date)
        #expect(updated.snapshotText.hasPrefix("Sort: [ ] Name [x] Date\n"))
    }

    @Test("Parent selection updates and reordered options preserve value-based selection")
    func parentUpdates() throws {
        // -- Arrange --
        var selection: Binding<Sort>?
        var options: Binding<[Sort]>?
        let renderer = ViewRenderer.make(
            Fixture(selection: .name) {
                selection = $0
                options = $1
            })
        _ = renderer.render(.now)

        // -- Act --
        selection?.wrappedValue = .date
        options?.wrappedValue = [.size, .date, .name]
        let reordered = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowRight)
        let updated = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(reordered.snapshotText.hasPrefix("Sort: [ ] Size [x] Date [ ] Name\n"))
        #expect(selection?.wrappedValue == .name)
        #expect(updated.snapshotText.hasPrefix("Sort: [ ] Size [ ] Date [x] Name\n"))
    }

    @Test("An empty picker has no selection and consumes only horizontal arrows")
    func emptyOptionsAndBubbling() throws {
        // -- Arrange --
        var selection = Sort.name
        var parentKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            Picker("Sort", selection: Binding(get: { selection }, set: { selection = $0 }), options: []) {
                Text($0.rawValue)
            }
            .onKeyPress { key in
                parentKeys.append(key)
                return .handled
            })

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.escape)
        _ = renderer.handle(.a)
        _ = renderer.handle(.tab)

        // -- Assert --
        #expect(frame.snapshotText == "Sort:")
        #expect(selection == .name)
        #expect(parentKeys == [.enter, .escape, .a, .tab])
    }

    @Test("A single custom option label stays selected without binding writes")
    func singleOption() throws {
        // -- Arrange --
        var writes = 0
        let renderer = ViewRenderer.make(
            Picker("Sort", selection: Binding(get: { Sort.date }, set: { _ in writes += 1 }), options: [.date]) { _ in
                HStack {
                    Text("By")
                    Text("date")
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.arrowRight)
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "Sort: [x] By date")
        #expect(writes == 0)
    }
}

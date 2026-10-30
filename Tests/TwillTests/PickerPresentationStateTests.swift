import Testing

@testable import Twill

@Suite("Picker presentation state and appearance")
@MainActor
struct PickerPresentationStateTests {
    private struct Fixture: View {
        @State private var selection = "B"
        @State private var options = ["A", "B", "C"]
        @State var presentation: PickerPresentation
        let capture: (Binding<String>, Binding<[String]>, Binding<PickerPresentation>) -> Void
        var body: some View {
            capture($selection, $options, $presentation)
            return Picker("Mode", selection: $selection, options: options, presentation: presentation)
        }
    }

    @Test("Updated/reordered options resolve effective values without rewriting stored selection")
    func changedOptions() throws {
        // -- Arrange --
        for presentation in [PickerPresentation.inline, .compact, .vertical] {
            var selection: Binding<String>?
            var options: Binding<[String]>?
            let renderer = ViewRenderer.make(
                Fixture(presentation: presentation) { selected, values, _ in
                    selection = selected
                    options = values
                })
            _ = renderer.render(.now)

            // -- Act --
            options?.wrappedValue = ["C", "A"]
            _ = renderer.render(.now)
            let retained = selection?.wrappedValue
            _ = renderer.handle(.arrowRight)
            let changed = try #require(renderer.render(.now).grid)

            // -- Assert --
            #expect(retained == "B")
            #expect(selection?.wrappedValue == "A")
            #expect(changed.snapshotText.contains("A"))
        }
    }

    @Test("Presentation changes retain the control focus owner and selected value")
    func changedPresentation() {
        // -- Arrange --
        var presentation: Binding<PickerPresentation>?
        var selection: Binding<String>?
        let renderer = ViewRenderer.make(
            Fixture(presentation: .inline) { selected, _, style in
                selection = selected
                presentation = style
            })
        _ = renderer.render(.now)
        weak var focused: ViewRenderer?
        focused = renderer.focusTarget()

        // -- Act --
        presentation?.wrappedValue = .vertical
        _ = renderer.render(.now)
        let retained = focused != nil && focused === renderer.focusTarget()
        _ = renderer.handle(.arrowDown)
        presentation?.wrappedValue = .compact
        _ = renderer.render(.now)

        // -- Assert --
        #expect(retained && focused === renderer.focusTarget())
        #expect(selection?.wrappedValue == "C")
    }

    private struct SelectionStyle: ControlStyle {
        func resolve(_ state: ControlState, in context: StyleContext) -> ControlAppearance {
            ControlAppearance(foreground: state.isSelected ? Color.green : Color.blue, focusEffect: .none)
        }
    }

    @Test("Control labels and value labels retain independent selection appearance")
    func selectionAppearance() throws {
        // -- Arrange --
        for mode in [PickerPresentation.inline, .compact, .vertical] {
            let renderer = ViewRenderer.make(
                Picker(
                    "Mode", selection: .constant("B"), options: ["A", "B"],
                    presentation: mode
                ).controlStyle(SelectionStyle()))

            // -- Act --
            let grid = try #require(renderer.render(.now).grid)
            let selected = (0..<grid.size.height).flatMap { row in
                (0..<grid.size.width).compactMap { column -> Color? in
                    grid[column, row] == .glyph("B", width: 1) ? grid.foreground(column: column, row: row) : nil
                }
            }

            // -- Assert --
            #expect(grid.foreground(column: 0, row: 0) == .blue)
            #expect(selected == [.green])
        }
    }

    @Test("Modal picker keys do not change an underlying picker")
    func modalIsolation() {
        // -- Arrange --
        var base = "A"
        var modal = "A"
        let renderer = ViewRenderer.make(
            Picker(
                "Base", selection: Binding(get: { base }, set: { base = $0 }),
                options: ["A", "B"], presentation: .vertical
            ).sheet(isPresented: .constant(true)) {
                Picker(
                    "Modal", selection: Binding(get: { modal }, set: { modal = $0 }),
                    options: ["A", "B"], presentation: .vertical)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)

        // -- Assert --
        #expect(base == "A" && modal == "B")
    }

    @Test("Cached compact resizing does not reevaluate the body")
    func cachedResize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(Counted(evaluated: { evaluations += 1 }))
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        let narrow = try #require(renderer.drawFrame(proposal: .init(width: 5)))
        let restored = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(narrow.snapshotText == "Mode:")
        #expect(restored == initial)
        #expect(evaluations == 1)
    }

    private struct Counted: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return Picker("Mode", selection: .constant("B"), options: ["A", "B"], presentation: .compact)
        }
    }

    @Test("Disabled pickers do not handle selection keys in any presentation")
    func disabled() {
        // -- Arrange --
        for mode in [PickerPresentation.inline, .compact, .vertical] {
            var writes = 0
            var completed = 0
            let renderer = ViewRenderer.make(
                VStack {
                    Picker(
                        "Mode", selection: Binding(get: { "A" }, set: { _ in writes += 1 }),
                        options: ["A", "B"], presentation: mode
                    ).disabled(true)
                    Button("Done") { completed += 1 }
                })
            _ = renderer.render(.now)

            // -- Act --
            _ = renderer.handle(.arrowRight)
            _ = renderer.handle(.enter)

            // -- Assert --
            #expect(writes == 0 && completed == 1)
        }
    }
}

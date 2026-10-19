import Testing

@testable import Twill

@Suite("State-aware control styling")
@MainActor
struct ControlStyleTests {
    private struct StateStyle: ControlStyle {
        func resolve(_ state: ControlState, in context: StyleContext) -> ControlAppearance {
            let color: Color =
                !state.isEnabled ? .brightBlack : state.isSelected ? .green : state.isFocused ? .red : .blue
            return ControlAppearance(
                foreground: color, attributes: state.isSelected ? [.underline] : [], focusEffect: .none)
        }
    }

    @ViewBuilder
    private func control(_ kind: ControlKind) -> some View {
        switch kind {
        case .button: Button("Run") {}
        case .toggle: Toggle("Flag", isOn: .constant(false))
        case .picker: Picker("Choice", selection: .constant(0), options: [0, 1]) { Text("\($0)") }
        case .slider: Slider("Level", value: .constant(0.5))
        case .stepper: Stepper("Count", value: .constant(1), in: 0...3)
        case .progress: ProgressView("Work", value: 0.5)
        case .disclosure: DisclosureGroup("More", isExpanded: .constant(false)) { Text("Child") }
        }
    }

    @Test("Every control family exposes live focus and disabled state", arguments: ControlKind.allCases)
    func families(kind: ControlKind) throws {
        // -- Arrange --
        let active = ViewRenderer.make(control(kind).controlStyle(StateStyle()))
        let disabled = ViewRenderer.make(control(kind).disabled(true).controlStyle(StateStyle()))

        // -- Act --
        let activeGrid = try #require(active.render(.now).grid)
        let disabledGrid = try #require(disabled.render(.now).grid)

        // -- Assert --
        #expect(activeGrid.foreground(column: 0, row: 0) == (kind == .progress ? .blue : .red))
        #expect(disabledGrid.foreground(column: 0, row: 0) == .brightBlack)
        #expect(!activeGrid.isFocused(column: 0, row: 0))
        #expect(!disabledGrid.isFocused(column: 0, row: 0))
    }

    @Test("Selected toggle state updates independently of focus appearance")
    func toggleSelection() throws {
        // -- Arrange --
        var isOn = true
        func view() -> some View {
            Toggle("Flag", isOn: Binding(get: { isOn }, set: { isOn = $0 })).controlStyle(StateStyle())
        }
        let renderer = ViewRenderer.make(view())
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.space)
        renderer.update(view(), at: .now)
        let changed = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(initial.foreground(column: 0, row: 0) == .green)
        #expect(initial.attributes(column: 0, row: 0) == [.underline])
        #expect(changed.foreground(column: 0, row: 0) == .red)
        #expect(changed.attributes(column: 0, row: 0).isEmpty)
        #expect(!isOn)
    }

    @Test("Picker options style their own selection while sharing the picker focus owner")
    func pickerSelection() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Picker("P", selection: .constant(0), options: [0, 1]) { Text("\($0)") }.controlStyle(StateStyle()))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "P: [x] 0 [ ] 1")
        #expect(grid.foreground(column: 3, row: 0) == .green)
        #expect(grid.foreground(column: 9, row: 0) == .red)
    }

    @Test("A selected list row does not replace the picker's own option selection")
    func pickerInsideSelectedRow() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            List([0], id: \.self, selection: .constant(0)) { _ in
                Picker("P", selection: .constant(0), options: [0, 1]) { Text("\($0)") }
            }.controlStyle(StateStyle()))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.attributes(column: 3, row: 0) == [.underline])
        #expect(grid.attributes(column: 9, row: 0).isEmpty)
    }

    @Test("Disclosure styling stays on the header rather than expanded content")
    func disclosureHeader() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            DisclosureGroup("More", isExpanded: .constant(true)) { Text("Child") }.controlStyle(StateStyle()))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .green)
        #expect(grid.foreground(column: 2, row: 1) == nil)
    }

    @Test("Nested control owners do not inherit another control's selected state")
    func nestedControlSelection() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Toggle(isOn: .constant(true)) { Button("Action") {} }.controlStyle(StateStyle()))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.attributes(column: 0, row: 0) == [.underline])
        #expect(grid.attributes(column: 4, row: 0).isEmpty)
    }

    @Test("Tab transfers styled focus with cached control content")
    func focusTransfer() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack {
                Button("A") {}
                Button("B") {}
            }.controlStyle(StateStyle()))
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.tab)
        let moved = try #require(renderer.drawFrame(proposal: .unspecified))

        // -- Assert --
        #expect(initial.foreground(column: 0, row: 0) == .red)
        #expect(initial.foreground(column: 2, row: 0) == .blue)
        #expect(moved.foreground(column: 0, row: 0) == .blue)
        #expect(moved.foreground(column: 2, row: 0) == .red)
    }

    @Test("Nested style declarations override locally and do not style ordinary text")
    func scopes() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack {
                Button("A") {}.controlStyle(AccentStyle())
                Button("B") {}
                Text("C")
            }.controlStyle(StateStyle()).tint(.magenta))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .magenta)
        #expect(grid.foreground(column: 2, row: 0) == .blue)
        #expect(grid.foreground(column: 4, row: 0) == nil)
    }

    private struct AccentStyle: ControlStyle {
        func resolve(_ state: ControlState, in context: StyleContext) -> ControlAppearance {
            ControlAppearance(foreground: TintStyle.tint)
        }
    }

    private struct TerminalDefault: Style {
        func resolve(in context: StyleContext) -> ResolvedStyle { ResolvedStyle(color: nil) }
    }

    @Test("Control foreground hierarchy contributes attributes unless appearance explicitly replaces them")
    func contextualForeground() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                Button("B") {}
                Button("C") {}.controlStyle(SecondaryStyle(attributes: []))
            }.foregroundStyle(Color.blue).bold().controlStyle(SecondaryStyle()))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 1, row: 0) == .blue)
        #expect(grid.foreground(column: 2, row: 0) == .blue)
        #expect(grid.attributes(column: 0, row: 0) == [.bold])
        #expect(grid.attributes(column: 1, row: 0) == [.bold, .dim])
        #expect(grid.attributes(column: 2, row: 0).isEmpty)
    }

    private struct SecondaryStyle: ControlStyle {
        var attributes: TextAttributes?

        func resolve(_ state: ControlState, in context: StyleContext) -> ControlAppearance {
            ControlAppearance(foreground: .secondary, attributes: attributes)
        }
    }

    private struct ClearStyle: ControlStyle {
        func resolve(_ state: ControlState, in context: StyleContext) -> ControlAppearance {
            ControlAppearance(
                foreground: TerminalDefault(), background: TerminalDefault(),
                attributes: [], focusEffect: .reversed)
        }
    }

    @Test("Appearance can clear inherited colors and attributes without changing activation")
    func explicitOverrides() throws {
        // -- Arrange --
        var first = 0
        var second = 0
        let renderer = ViewRenderer.make(
            HStack {
                Button("A") { first += 1 }
                Button("B") { second += 1 }.foregroundStyle(Color.red).backgroundStyle(Color.blue).bold()
                    .controlStyle(ClearStyle())
            })
        let grid = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(grid.foreground(column: 2, row: 0) == nil)
        #expect(grid.background(column: 2, row: 0) == nil)
        #expect(grid.attributes(column: 2, row: 0).isEmpty)
        #expect(grid.isFocused(column: 2, row: 0))
        #expect(first == 1 && second == 0)
    }

    @Test("Hiding reverse-video emphasis does not hide an editing caret or change focus routing")
    func caretIndependence() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Button(action: {}, label: { TextField("", text: .constant("abc")) }).controlStyle(StateStyle()))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(!grid.isFocused(column: 0, row: 0))
        #expect(renderer.caretPosition != nil)
    }
}

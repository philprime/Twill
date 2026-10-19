import Testing

@testable import Twill

@Suite("Read-only editing policy")
@MainActor
struct ReadOnlyEditingTests {
    enum Kind: CaseIterable, Sendable { case field, secure, editor }

    @ViewBuilder
    private func input(_ kind: Kind, text: Binding<String>, mode: TextEditingMode) -> some View {
        switch kind {
        case .field: TextField("Value", text: text, editingMode: mode)
        case .secure: SecureField("Value", text: text, editingMode: mode)
        case .editor: TextEditor(text: text, editingMode: mode)
        }
    }

    @Test("Read-only controls retain focus/navigation and consume edits without mutation", arguments: Kind.allCases)
    func editingPolicy(kind: Kind) throws {
        // -- Arrange --
        var text = "one 界"
        var writes = 0
        var submitted: [String] = []
        var outerKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            input(
                kind,
                text: Binding(
                    get: { text },
                    set: {
                        text = $0
                        writes += 1
                    }), mode: .readOnly
            )
            .onSubmit { submitted.append(text) }
            .onKeyPress {
                outerKeys.append($0)
                return .handled
            })
        _ = renderer.render(.now)

        // -- Act --
        for key: KeyEvent in [
            .home, .x, .backspace, .delete, .backspace.withModifiers(.control),
            .delete.withModifiers(.alt), .enter, .arrowRight.withModifiers(.control), .end,
        ] {
            _ = renderer.handle(key)
        }
        let frame = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.controlS)
        _ = renderer.handle(.escape)

        // -- Assert --
        #expect(text == "one 界" && writes == 0)
        #expect(frame.snapshotText == (kind == .secure ? "•••••" : "one 界" + (kind == .editor ? " " : "")))
        #expect(renderer.caretPosition == CellPosition(column: kind == .secure ? 5 : 6, row: 0))
        #expect(submitted == (kind == .editor ? [] : [text]))
        #expect(outerKeys == [.controlS, .escape])
    }

    @Test(
        "Editing-mode updates preserve the mounted caret and external values remain visible", arguments: Kind.allCases)
    func modeUpdates(kind: Kind) throws {
        // -- Arrange --
        var text = "one two"
        let binding = Binding(get: { text }, set: { text = $0 })
        let renderer = ViewRenderer.make(input(kind, text: binding, mode: .editable))
        _ = renderer.render(.now)
        _ = renderer.handle(.home)
        _ = renderer.handle(.arrowRight)

        // -- Act --
        renderer.update(input(kind, text: binding, mode: .readOnly), at: .now)
        _ = renderer.handle(.x)
        _ = renderer.handle(.delete)
        _ = renderer.render(.now)
        let retained = renderer.caretPosition
        text = "new words"
        renderer.update(input(kind, text: binding, mode: .readOnly), at: .now)
        let external = try #require(renderer.render(.now).grid)
        renderer.update(input(kind, text: binding, mode: .editable), at: .now)
        _ = renderer.handle(.x)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(retained == CellPosition(column: 1, row: 0))
        #expect(external.snapshotText == (kind == .secure ? "•••••••••" : "new words" + (kind == .editor ? " " : "")))
        #expect(text == "nxew words")
    }

    @Test("Read-only multiline editors keep page navigation and viewport reveal")
    func viewportNavigation() throws {
        // -- Arrange --
        var text = "one\nsecond\nthree\nfour"
        let original = text
        let renderer = ViewRenderer.make(
            TextEditor(text: Binding(get: { text }, set: { text = $0 }), editingMode: .readOnly)
                .frame(width: 4, height: 2))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.home)
        _ = renderer.handle(.pageUp)
        _ = renderer.handle(.x)
        _ = renderer.handle(.enter)
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(text == original)
        #expect(frame.snapshotText == "seco\nthre")
        #expect(renderer.caretPosition == .zero)
    }

    @Test("Read-only controls remain Tab stops while disabled controls do not")
    func focusEligibility() {
        // -- Arrange --
        var text = "value"
        var activations = 0
        let renderer = ViewRenderer.make(
            HStack {
                TextField("Value", text: Binding(get: { text }, set: { text = $0 }), editingMode: .readOnly)
                TextField("Disabled", text: .constant("hidden focus"), editingMode: .readOnly).disabled(true)
                Button("Next") { activations += 1 }
            })
        _ = renderer.render(.now)
        let initial = renderer.caretPosition

        // -- Act --
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.shiftTab)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(initial == CellPosition(column: 5, row: 0))
        #expect(renderer.caretPosition == initial)
        #expect(activations == 1)
    }
}

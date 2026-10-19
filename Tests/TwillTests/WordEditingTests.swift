import Testing

@testable import Twill

@Suite("Shared word editing")
@MainActor
struct WordEditingTests {
    enum Kind: CaseIterable, Sendable { case field, secure, editor }

    @ViewBuilder
    private func input(_ kind: Kind, text: Binding<String>) -> some View {
        switch kind {
        case .field: TextField("Value", text: text)
        case .secure: SecureField("Value", text: text)
        case .editor: TextEditor(text: text)
        }
    }

    @Test("Alt and Control word movement and deletion use identical grapheme boundaries", arguments: Kind.allCases)
    func sharedBoundaries(kind: Kind) throws {
        // -- Arrange --
        var text = "one, two_界 👩‍💻!"
        var outerKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            input(kind, text: Binding(get: { text }, set: { text = $0 }))
                .onKeyPress {
                    outerKeys.append($0)
                    return .handled
                })
        _ = renderer.render(.now)
        var values: [String] = []

        // -- Act --
        _ = renderer.handle(.arrowLeft.withModifiers(.control))
        _ = renderer.render(.now)
        let punctuationStart = renderer.caretPosition
        _ = renderer.handle(.arrowLeft.withModifiers(.alt))
        _ = renderer.handle(.arrowRight.withModifiers(.control))
        for key: KeyEvent in [
            .backspace.withModifiers(.alt), .delete.withModifiers(.control),
            .backspace.withModifiers(.alt), .backspace.withModifiers(.control),
        ] {
            _ = renderer.handle(key)
            values.append(text)
            let frame = try #require(renderer.render(.now).grid)
            if kind == .secure, !text.isEmpty {
                #expect(frame.snapshotText == String(repeating: "•", count: text.count))
            }
        }

        // -- Assert --
        #expect(punctuationStart == CellPosition(column: kind == .secure ? 11 : 12, row: 0))
        #expect(values == ["one,  👩‍💻!", "one, ", "one", ""])
        #expect(outerKeys.isEmpty)
    }

    @Test("Word boundaries preserve combined characters and treat newlines as whitespace")
    func multilineWords() {
        // -- Arrange --
        var text = "e\u{301}clair\n界 two"
        let renderer = ViewRenderer.make(TextEditor(text: Binding(get: { text }, set: { text = $0 })))
        _ = renderer.render(.now)

        // -- Act --
        for _ in 0..<3 { _ = renderer.handle(.arrowLeft.withModifiers(.alt)) }
        _ = renderer.handle(.delete.withModifiers(.alt))
        let first = text
        _ = renderer.handle(.delete.withModifiers(.control))
        _ = renderer.render(.now)

        // -- Assert --
        #expect(first == "\n界 two")
        #expect(text == " two")
        #expect(renderer.caretPosition == .zero)
    }

    @Test("Word editing at empty and endpoint boundaries performs no binding writes", arguments: Kind.allCases)
    func boundaries(kind: Kind) {
        // -- Arrange --
        var text = ""
        var writes = 0
        let renderer = ViewRenderer.make(
            input(
                kind,
                text: Binding(
                    get: { text },
                    set: {
                        text = $0
                        writes += 1
                    })))
        _ = renderer.render(.now)

        // -- Act --
        for key: KeyEvent in [
            .arrowLeft.withModifiers(.control), .arrowRight.withModifiers(.alt),
            .backspace.withModifiers(.control), .delete.withModifiers(.alt),
        ] {
            _ = renderer.handle(key)
        }

        // -- Assert --
        #expect(text.isEmpty)
        #expect(writes == 0)
    }
}

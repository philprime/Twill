/// A field that accepts text whenever focused. The binding owns its value;
/// the mounted control retains its insertion point. Home/End reach the endpoints,
/// and Delete removes the next complete character without moving the caret.
public struct TextField: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    @State private var caret: Int?
    private let prompt: String
    private let text: Binding<String>
    private let isSecure: Bool

    /// Creates a single-line editor with bound text and a prompt displayed while the value is empty.
    public init(_ prompt: String, text: Binding<String>) {
        self.init(prompt, text: text, isSecure: false)
    }

    init(_ prompt: String, text: Binding<String>, isSecure: Bool) {
        self.prompt = prompt
        self.text = text
        self.isSecure = isSecure
    }

    private func handle(_ key: KeyEvent) -> KeyPressResult {
        let value = text.wrappedValue
        let offset = min(caret ?? value.count, value.count)
        switch key.key {
        case .character(let character):
            // Command chords are not text insertion and must remain available to scoped actions.
            guard key.modifiers.isDisjoint(with: [.control, .alt, .superKey, .hyper, .meta]) else { return .ignored }
            var updated = value
            updated.insert(character, at: updated.index(updated.startIndex, offsetBy: offset))
            text.wrappedValue = updated
            caret = min(offset + 1, updated.count)
        case .backspace:
            if offset > 0 {
                var updated = value
                updated.remove(at: updated.index(updated.startIndex, offsetBy: offset - 1))
                text.wrappedValue = updated
                caret = offset - 1
            }
        case .delete:
            if key.modifiers.isEmpty, offset < value.count {
                var updated = value
                updated.remove(at: updated.index(updated.startIndex, offsetBy: offset))
                text.wrappedValue = updated
                caret = offset
            }
        case .arrowLeft, .arrowRight, .home, .end:
            move(key, offset: offset, count: value.count)
        case .arrowUp, .arrowDown, .pageUp, .pageDown, .insert, .function:
            break
        default:
            return .ignored
        }
        return .handled
    }

    private func move(_ key: KeyEvent, offset: Int, count: Int) {
        guard key.modifiers.isEmpty else { return }
        let destination: Int
        switch key.key {
        case .arrowLeft: destination = max(0, offset - 1)
        case .arrowRight: destination = min(count, offset + 1)
        case .home: destination = 0
        case .end: destination = count
        default: return
        }
        if destination != offset { caret = destination }
    }
}

extension TextField: PrimitiveView {
    func makeDescription() -> ViewDescription {
        let value = text.wrappedValue
        // Mask before constructing drawing data so frames and drawing diagnostics
        // never contain the bound secret. Caret widths must use that same mask.
        let renderedValue = isSecure ? String(repeating: "•", count: value.count) : value
        let displayed = value.isEmpty ? prompt : renderedValue
        // Caret positions use rendered cell widths, not character indices.
        let prefix = String(renderedValue.prefix(min(caret ?? value.count, value.count)))
        let caretColumn = TextDrawing(prefix).sizeThatFits(.unspecified).width
        return .textField(
            TextFieldDescription(
                drawing: TextDrawing(displayed), caretColumn: caretColumn, handle: { handle($0) },
                blur: { if caret != nil { caret = nil } }))
    }
}

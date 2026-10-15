/// A field that accepts text whenever focused. The binding owns its value;
/// the mounted control retains its insertion point.
public struct TextField: View {
    public typealias Body = Never
    @State private var caret: Int?
    private let prompt: String
    private let text: Binding<String>

    public init(_ prompt: String, text: Binding<String>) {
        self.prompt = prompt
        self.text = text
    }

    private func handle(_ key: KeyEvent) -> KeyPressResult {
        let value = text.wrappedValue
        let offset = min(caret ?? value.count, value.count)
        switch key.key {
        case .character(let character):
            guard key.modifiers.isDisjoint(with: [.control, .alt, .superKey, .hyper, .meta]) else { return .handled }
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
        case .arrowLeft:
            if key.modifiers.isEmpty, offset > 0 { caret = offset - 1 }
        case .arrowRight:
            if key.modifiers.isEmpty, offset < value.count { caret = offset + 1 }
        case .arrowUp, .arrowDown, .tab, .pageUp, .pageDown, .home, .end, .insert, .delete, .function:
            break
        default:
            return .ignored
        }
        return .handled
    }
}

struct TextFieldDescription {
    let drawing: TextDrawing
    let caretColumn: Int?
    let handle: @MainActor (KeyEvent) -> KeyPressResult
    let blur: @MainActor () -> Void
}

extension TextField: PrimitiveView {
    func makeDescription() -> ViewDescription {
        let value = text.wrappedValue
        let displayed = value.isEmpty ? prompt : value
        // Caret positions use rendered cell widths, not character indices.
        let prefix = String(value.prefix(min(caret ?? value.count, value.count)))
        let caretColumn = TextDrawing(prefix).sizeThatFits(.unspecified).width
        return .textField(
            TextFieldDescription(
                drawing: TextDrawing(displayed), caretColumn: caretColumn, handle: { handle($0) },
                blur: { if caret != nil { caret = nil } }))
    }
}

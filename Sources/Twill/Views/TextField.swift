/// A focusable field whose text belongs to the binding owner and whose editing
/// mode and insertion point belong to its mounted identity.
public struct TextField: View {
    public typealias Body = Never
    @State private var isEditing = false
    @State private var caret = 0
    private let prompt: String
    private let text: Binding<String>

    public init(_ prompt: String, text: Binding<String>) {
        self.prompt = prompt
        self.text = text
    }

    private func handle(_ key: KeyEvent) -> KeyPressResult {
        switch key.key {
        case .enter where key.modifiers.isEmpty:
            if isEditing {
                isEditing = false
            } else {
                caret = text.wrappedValue.count
                isEditing = true
            }
            return .handled
        case .escape where key.modifiers.isEmpty:
            guard isEditing else { return .ignored }
            isEditing = false
            return .handled
        default:
            return isEditing ? edit(key) : .ignored
        }
    }

    private func edit(_ key: KeyEvent) -> KeyPressResult {
        let value = text.wrappedValue
        let offset = min(caret, value.count)
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
}

extension TextField: PrimitiveView {
    func makeDescription() -> ViewDescription {
        let value = text.wrappedValue
        let displayed = value.isEmpty ? (isEditing ? " " : prompt) : value
        // Caret positions use rendered cell widths, not character indices.
        let prefix = String(value.prefix(min(caret, value.count)))
        let caretColumn = isEditing ? TextDrawing(prefix).sizeThatFits(.unspecified).width : nil
        return .textField(
            TextFieldDescription(drawing: TextDrawing(displayed), caretColumn: caretColumn, handle: { handle($0) }))
    }
}

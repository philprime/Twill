/// A bound field with a mounted insertion point. Editable fields accept text
/// whenever focused; read-only fields retain navigation and submit routing. Home/End reach the endpoints,
/// and Delete removes the next complete character without moving the caret.
public struct TextField: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    @State private var caret: Int?
    private let prompt: String
    private let text: Binding<String>
    private let isSecure: Bool
    private let editingMode: TextEditingMode
    private let onVerticalMove: (@MainActor (KeyEvent) -> Void)?

    /// Creates a single-line editor with a prompt displayed while the value is empty.
    /// Read-only mode consumes attempted edits without writing the binding.
    public init(_ prompt: String, text: Binding<String>, editingMode: TextEditingMode = .editable) {
        self.init(prompt, text: text, isSecure: false, editingMode: editingMode)
    }

    init(_ prompt: String, text: Binding<String>, onVerticalMove: @escaping @MainActor (KeyEvent) -> Void) {
        self.init(prompt, text: text, isSecure: false, editingMode: .editable, onVerticalMove: onVerticalMove)
    }

    init(
        _ prompt: String, text: Binding<String>, isSecure: Bool, editingMode: TextEditingMode,
        onVerticalMove: (@MainActor (KeyEvent) -> Void)? = nil
    ) {
        self.prompt = prompt
        self.text = text
        self.isSecure = isSecure
        self.editingMode = editingMode
        self.onVerticalMove = onVerticalMove
    }

    private func handle(_ key: KeyEvent) -> KeyPressResult {
        let value = text.wrappedValue
        let offset = min(caret ?? value.count, value.count)
        switch key.key {
        case .character(let character):
            // Command chords are not text insertion and must remain available to scoped actions.
            guard key.modifiers.isDisjoint(with: [.control, .alt, .superKey, .hyper, .meta]) else { return .ignored }
            guard editingMode == .editable else { return .handled }
            var updated = value
            updated.insert(character, at: updated.index(updated.startIndex, offsetBy: offset))
            text.wrappedValue = updated
            caret = min(offset + 1, updated.count)
        case .backspace, .delete:
            delete(key, offset: offset, value: value)
        case .arrowLeft, .arrowRight, .home, .end:
            move(key, offset: offset, value: value)
        case .arrowUp, .arrowDown:
            onVerticalMove?(key)
        case .pageUp, .pageDown, .insert, .function:
            break
        default:
            return .ignored
        }
        return .handled
    }

    private func delete(_ key: KeyEvent, offset: Int, value: String) {
        guard editingMode == .editable else { return }
        let backwards = key.key == .backspace
        guard backwards || key.modifiers.isEmpty || key.modifiers.isWordEditing else { return }
        let destination =
            key.modifiers.isWordEditing
            ? TextWordNavigation(value).destination(from: offset, backwards: backwards)
            : (backwards ? max(0, offset - 1) : min(value.count, offset + 1))
        let lower = min(offset, destination)
        let upper = max(offset, destination)
        guard lower < upper else { return }
        var updated = value
        let start = updated.index(updated.startIndex, offsetBy: lower)
        let end = updated.index(updated.startIndex, offsetBy: upper)
        updated.removeSubrange(start..<end)
        text.wrappedValue = updated
        caret = min(lower, updated.count)
    }

    private func move(_ key: KeyEvent, offset: Int, value: String) {
        if key.modifiers.isWordEditing, key.key == .arrowLeft || key.key == .arrowRight {
            let destination = TextWordNavigation(value).destination(from: offset, backwards: key.key == .arrowLeft)
            if destination != offset { caret = destination }
            return
        }
        guard key.modifiers.isEmpty else { return }
        let destination: Int
        switch key.key {
        case .arrowLeft: destination = max(0, offset - 1)
        case .arrowRight: destination = min(value.count, offset + 1)
        case .home: destination = 0
        case .end: destination = value.count
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

/// A bound multiline editor with a mounted caret and a scrolling viewport.
///
/// In editable mode, Enter inserts a newline rather than submitting. Tab and Shift-Tab move
/// between controls, and Escape and modified Enter route to enclosing handlers. Long
/// lines scroll horizontally without soft wrapping. Focus changes retain the
/// insertion point. The terminal host alone presents the hardware cursor.
public struct TextEditor: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    @State private var caret: Int?
    @State private var preferredColumn: Int?
    private let text: Binding<String>
    private let editingMode: TextEditingMode

    /// Creates a multiline editor whose text is owned by the supplied binding.
    /// Read-only mode retains caret/viewport navigation and consumes attempted edits.
    public init(text: Binding<String>, editingMode: TextEditingMode = .editable) {
        self.text = text
        self.editingMode = editingMode
    }

    private func handle(_ key: KeyEvent, pageHeight: Int) -> KeyPressResult {
        let value = text.wrappedValue
        let offset = min(caret ?? value.count, value.count)
        switch key.key {
        case .character(let character):
            // Command chords are not text insertion and must remain available to scoped actions.
            guard key.modifiers.isDisjoint(with: [.control, .alt, .superKey, .hyper, .meta]) else { return .ignored }
            replace(offset..<offset, with: String(character))
        case .enter:
            guard key.modifiers.isEmpty else { return .ignored }
            replace(offset..<offset, with: "\n")
        case .backspace, .delete:
            delete(key, at: offset)
        case .arrowLeft, .arrowRight, .arrowUp, .arrowDown, .home, .end, .pageUp, .pageDown:
            navigate(key, offset: offset, pageHeight: pageHeight)
        default:
            return .ignored
        }
        return .handled
    }

    private func delete(_ key: KeyEvent, at offset: Int) {
        let backwards = key.key == .backspace
        let destination =
            key.modifiers.isWordEditing
            ? TextWordNavigation(text.wrappedValue).destination(from: offset, backwards: backwards)
            : (backwards ? max(0, offset - 1) : min(text.wrappedValue.count, offset + 1))
        let lower = min(offset, destination)
        let upper = max(offset, destination)
        if lower < upper { replace(lower..<upper, with: "") }
    }

    private func replace(_ range: Range<Int>, with inserted: String) {
        guard editingMode == .editable else { return }
        var value = text.wrappedValue
        let start = value.index(value.startIndex, offsetBy: range.lowerBound)
        let end = value.index(value.startIndex, offsetBy: range.upperBound)
        // Terminal input arrives as scalars, which can join a preceding grapheme.
        // Counting the resulting prefix keeps insertion before any following text.
        let prefixCount = (String(value[..<start]) + inserted).count
        value.replaceSubrange(start..<end, with: inserted)
        text.wrappedValue = value
        caret = min(prefixCount, value.count)
        preferredColumn = nil
    }

    private func navigate(_ key: KeyEvent, offset: Int, pageHeight: Int) {
        if key.modifiers.isWordEditing, key.key == .arrowLeft || key.key == .arrowRight {
            caret = TextWordNavigation(text.wrappedValue).destination(from: offset, backwards: key.key == .arrowLeft)
            preferredColumn = nil
        } else if key.modifiers.isEmpty {
            move(key, offset: offset, pageHeight: pageHeight)
        }
    }

    private func move(_ key: KeyEvent, offset: Int, pageHeight: Int) {
        let content = TextEditorContent(text.wrappedValue)
        let position = content.position(at: offset)
        switch key {
        case .arrowUp, .arrowDown, .pageUp, .pageDown:
            let column = preferredColumn ?? position.column
            let distance = key == .pageUp || key == .pageDown ? max(1, pageHeight) : 1
            let direction = key == .arrowUp || key == .pageUp ? -1 : 1
            caret = content.offset(row: position.row + direction * distance, column: column)
            preferredColumn = column
            return
        case .arrowLeft: caret = max(0, offset - 1)
        case .arrowRight: caret = min(text.wrappedValue.count, offset + 1)
        case .home: caret = content.offset(row: position.row, column: 0)
        case .end: caret = content.offset(row: position.row, column: content.width)
        default: break
        }
        preferredColumn = nil
    }
}

extension TextEditor: PrimitiveView {
    func makeDescription() -> ViewDescription {
        let value = text.wrappedValue
        let content = TextEditorContent(value)
        return .textEditor(
            TextEditorDescription(
                content: content, caret: content.position(at: min(caret ?? value.count, value.count)),
                handle: { handle($0, pageHeight: $1) }))
    }
}

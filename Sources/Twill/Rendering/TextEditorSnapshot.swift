/// Presentation owns immutable text and caret data, not editing callbacks or nodes.
struct TextEditorSnapshot {
    let content: TextEditorContent
    let caret: Int
    let upstream: Bool
    let lineBreakMode: Text.LineBreakMode

    func layout(width: Int?) -> TextEditorLayout {
        TextEditorLayout(content: content, width: width, mode: lineBreakMode)
    }
}

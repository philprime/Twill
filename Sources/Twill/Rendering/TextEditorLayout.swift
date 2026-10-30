/// Visual rows retain logical grapheme offsets. Wrapping never inserts model
/// newlines or discards whitespace, and the final viewport cell holds the caret.
struct TextEditorLayout {
    let lines: [TextEditorContent.Line]
    let width: Int
    let drawingWidth: Int

    init(content: TextEditorContent, width: Int?, mode: Text.LineBreakMode) {
        guard let width, mode != .clipping else {
            lines = content.lines
            self.width = content.width
            drawingWidth = content.width
            return
        }
        let capacity = max(0, width - 1)
        self.width = width
        drawingWidth = capacity
        lines = content.lines.flatMap { line in
            let characters = Array(line.text)
            let glyphs: [TextDrawing.Glyph] = characters.indices.map {
                (characters[$0], line.columns[$0 + 1] - line.columns[$0])
            }
            return TextLineWrapping().ranges(for: glyphs, width: max(1, capacity), mode: mode, preservesSpaces: true)
                .map { TextEditorContent.Line(start: line.start + $0.lowerBound, text: String(characters[$0])) }
        }
    }

    func position(at offset: Int, upstream: Bool) -> CellPosition {
        var row = lines.lastIndex { $0.start <= offset } ?? 0
        if upstream, row > 0, lines[row].start == offset, end(of: row - 1) == offset { row -= 1 }
        let line = lines[row]
        let column = line.columns[min(offset - line.start, line.columns.count - 1)]
        return CellPosition(column: min(column, drawingWidth), row: row)
    }

    func destination(row: Int, column: Int) -> (offset: Int, upstream: Bool) {
        let row = min(max(0, row), lines.count - 1)
        let line = lines[row]
        let offset = line.start + (line.columns.lastIndex { $0 <= column } ?? 0)
        let upstream = row + 1 < lines.count && offset == end(of: row) && lines[row + 1].start == offset
        return (offset, upstream)
    }

    private func end(of row: Int) -> Int { lines[row].start + lines[row].columns.count - 1 }
}

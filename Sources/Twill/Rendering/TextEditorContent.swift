/// Logical lines share sanitized drawing and display-cell geometry with `Text`.
struct TextEditorContent {
    struct Line {
        let start: Int
        let drawing: TextDrawing
        let columns: [Int]

        init(start: Int, text: String) {
            self.start = start
            drawing = TextDrawing(text)
            var columns = [0]
            for character in text {
                columns.append(columns.last! + TextDrawing(String(character)).sizeThatFits(.unspecified).width)
            }
            self.columns = columns
        }
    }

    let lines: [Line]
    let width: Int

    init(_ text: String) {
        var start = 0
        lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map { segment in
            let line = Line(start: start, text: String(segment))
            start += segment.count + 1
            return line
        }
        // Keep an insertion cell after even a full-width line, including empty text.
        width = (lines.map { $0.columns.last! }.max() ?? 0) + 1
    }

    func position(at offset: Int) -> CellPosition {
        let row = lines.lastIndex { $0.start <= offset } ?? 0
        let line = lines[row]
        return CellPosition(column: line.columns[min(offset - line.start, line.columns.count - 1)], row: row)
    }

    func offset(row: Int, column: Int) -> Int {
        let line = lines[min(max(0, row), lines.count - 1)]
        // A requested column inside a wide grapheme lands before that grapheme.
        return line.start + (line.columns.lastIndex { $0 <= column } ?? 0)
    }
}

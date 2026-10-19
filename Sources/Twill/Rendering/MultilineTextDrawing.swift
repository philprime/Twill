/// Public text reflows from sanitized graphemes without reevaluating view bodies.
/// Editing fields and terminal chrome retain the single-line TextDrawing contract.
struct MultilineTextDrawing: PrimitiveDrawing {
    private typealias Glyph = TextDrawing.Glyph
    private struct Row {
        let line: Int
        let range: Range<Int>
    }
    private struct Layout {
        let rows: [[Glyph]]
        let width: Int
    }
    private let lines: [[Glyph]]
    private var configuration = TextLayoutConfiguration()

    init(_ text: String) {
        lines = text.split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" }
            .map { TextDrawing(String($0)).glyphs }
    }

    func configured(_ configuration: TextLayoutConfiguration) -> Self {
        var result = self
        result.configuration = configuration
        return result
    }

    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
        let layout = layout(width: proposal.width, height: proposal.height)
        return CellSize(width: layout.width, height: layout.rows.count)
    }

    func draw(in context: inout DrawingContext) {
        let layout = layout(width: context.regionSize.width, height: context.regionSize.height)
        for (row, glyphs) in layout.rows.enumerated() {
            var column = 0
            for glyph in glyphs {
                context.draw(glyph.character, width: glyph.width, column: column, row: row)
                column += glyph.width
            }
        }
    }

    private func layout(width: Int?, height: Int?) -> Layout {
        guard width != 0, height != 0 else { return Layout(rows: [], width: 0) }
        let source = sourceRows(width: width)
        let count = min(source.count, height ?? source.count, configuration.lineLimit ?? source.count)
        var rows = source.prefix(count).map { Array(lines[$0.line][$0.range]) }
        var truncated = false
        if let mode = configuration.effectiveTruncationMode {
            for index in rows.indices {
                let budget = width ?? (columns(rows[index]) + 1)
                if index == count - 1, source.count > count {
                    rows[index] = TextTruncation().apply(remaining(from: source[index]), width: budget, mode: mode)
                    truncated = true
                } else if let width, columns(rows[index]) > width {
                    rows[index] = TextTruncation().apply(rows[index], width: width, mode: mode)
                    truncated = true
                }
            }
        }
        let naturalWidth = rows.map(columns).max() ?? 0
        // Preserve the offered width after ellipsis placement. Reflowing at a
        // narrower measured width could choose different middle-truncation ends.
        let measuredWidth = width.map { truncated ? $0 : min($0, naturalWidth) } ?? naturalWidth
        return Layout(rows: rows, width: measuredWidth)
    }

    private func sourceRows(width: Int?) -> [Row] {
        lines.indices.flatMap { line in
            TextLineWrapping().ranges(for: lines[line], width: width, mode: configuration.lineBreakMode)
                .map { Row(line: line, range: $0) }
        }
    }

    private func remaining(from row: Row) -> [Glyph] {
        var glyphs = Array(lines[row.line][row.range.lowerBound...])
        for line in lines.dropFirst(row.line + 1) {
            glyphs.append((" ", 1))
            glyphs.append(contentsOf: line)
        }
        return glyphs
    }

    private func columns(_ glyphs: [Glyph]) -> Int { glyphs.reduce(0) { $0 + $1.width } }
}

/// Drawing is separate from view evaluation so layout and resize can reuse content.
protocol PrimitiveDrawing {
    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize
    func draw(in context: inout DrawingContext)
}

struct TextDrawing: PrimitiveDrawing {
    private let glyphs: [(character: Character, width: Int)]
    private let size: CellSize

    init(_ text: String) {
        // Text is data, never terminal commands. Preserve the existing single-line
        // text policy while measuring the sanitized graphemes in terminal columns.
        let sanitized = String(
            text.unicodeScalars.map {
                $0.properties.generalCategory == .control ? Character(" ") : Character(String($0))
            })
        glyphs = sanitized.map { character in
            // A standalone combining mark must not modify a previously drawn cell.
            let first = character.unicodeScalars.first!
            let isMark =
                first.properties.generalCategory == .nonspacingMark
                || first.properties.generalCategory == .enclosingMark
                || first.properties.generalCategory == .spacingMark
            let visible: Character
            if first.properties.generalCategory == .format {
                visible = " "
            } else {
                visible = isMark ? Character("◌" + String(character)) : character
            }
            return (visible, TerminalCharacterWidth.columns(for: visible))
        }
        size = CellSize(width: glyphs.reduce(0) { $0 + $1.width }, height: 1)
    }

    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
        proposal.constrain(size)
    }

    func draw(in context: inout DrawingContext) {
        var column = 0
        for glyph in glyphs {
            context.draw(glyph.character, width: glyph.width, column: column, row: 0)
            column += glyph.width
        }
    }
}

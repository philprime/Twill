enum TerminalCell: Equatable {
    case blank
    case glyph(Character, width: Int)
    case continuation
}

/// A value snapshot. Wide glyphs own both their leading and continuation cells.
struct CellGrid: Equatable {
    let size: CellSize
    private var cells: [TerminalCell]

    init(size: CellSize) {
        self.size = size
        cells = Array(repeating: .blank, count: size.width * size.height)
    }

    subscript(column: Int, row: Int) -> TerminalCell {
        guard column >= 0, row >= 0, column < size.width, row < size.height else { return .blank }
        return cells[row * size.width + column]
    }

    mutating func put(_ character: Character, width: Int, column: Int, row: Int) {
        for column in column..<(column + width) { eraseGlyph(column: column, row: row) }
        cells[row * size.width + column] = character == " " ? .blank : .glyph(character, width: width)
        if width == 2 { cells[row * size.width + column + 1] = .continuation }
    }

    private mutating func eraseGlyph(column: Int, row: Int) {
        let index = row * size.width + column
        switch cells[index] {
        case .continuation:
            cells[index - 1] = .blank
        case .glyph(_, width: 2):
            cells[index + 1] = .blank
        default:
            break
        }
        cells[index] = .blank
    }
}

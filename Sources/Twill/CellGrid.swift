enum TerminalCell: Equatable {
    case blank
    case glyph(Character, width: Int)
    case continuation
}

/// A value snapshot. Wide glyphs own both their leading and continuation cells.
struct CellGrid: Equatable {
    let size: CellSize
    private var cells: [TerminalCell]
    private var focusedCells: [Bool]

    init(size: CellSize) {
        self.size = size
        cells = Array(repeating: .blank, count: size.width * size.height)
        focusedCells = Array(repeating: false, count: size.width * size.height)
    }

    subscript(column: Int, row: Int) -> TerminalCell {
        guard column >= 0, row >= 0, column < size.width, row < size.height else { return .blank }
        return cells[row * size.width + column]
    }

    func isFocused(column: Int, row: Int) -> Bool {
        guard column >= 0, row >= 0, column < size.width, row < size.height else { return false }
        return focusedCells[row * size.width + column]
    }

    mutating func put(_ character: Character, width: Int, column: Int, row: Int, focused: Bool = false) {
        for column in column..<(column + width) { eraseGlyph(column: column, row: row) }
        let index = row * size.width + column
        cells[index] = character == " " ? .blank : .glyph(character, width: width)
        focusedCells[index] = focused
        if width == 2 {
            cells[index + 1] = .continuation
            focusedCells[index + 1] = focused
        }
    }

    private mutating func eraseGlyph(column: Int, row: Int) {
        let index = row * size.width + column
        switch cells[index] {
        case .continuation:
            cells[index - 1] = .blank
            focusedCells[index - 1] = false
        case .glyph(_, width: 2):
            cells[index + 1] = .blank
            focusedCells[index + 1] = false
        default:
            break
        }
        cells[index] = .blank
        focusedCells[index] = false
    }
}

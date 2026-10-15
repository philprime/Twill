enum TerminalCell: Equatable {
    case blank
    case glyph(Character, width: Int)
    case continuation
}

/// A value snapshot. Wide glyphs own both their leading and continuation cells.
struct CellGrid: Equatable {
    let size: CellSize
    var images: [ImagePlacement] = []
    private var cells: [TerminalCell]
    private var focusedCells: [Bool]
    private var foregrounds: [Color?]
    private var backgrounds: [Color?]

    init(size: CellSize) {
        self.size = size
        cells = Array(repeating: .blank, count: size.width * size.height)
        focusedCells = Array(repeating: false, count: size.width * size.height)
        foregrounds = Array(repeating: nil, count: size.width * size.height)
        backgrounds = Array(repeating: nil, count: size.width * size.height)
    }

    subscript(column: Int, row: Int) -> TerminalCell {
        guard column >= 0, row >= 0, column < size.width, row < size.height else { return .blank }
        return cells[row * size.width + column]
    }

    func isFocused(column: Int, row: Int) -> Bool {
        guard column >= 0, row >= 0, column < size.width, row < size.height else { return false }
        return focusedCells[row * size.width + column]
    }

    func foreground(column: Int, row: Int) -> Color? {
        guard column >= 0, row >= 0, column < size.width, row < size.height else { return nil }
        return foregrounds[row * size.width + column]
    }

    func background(column: Int, row: Int) -> Color? {
        guard column >= 0, row >= 0, column < size.width, row < size.height else { return nil }
        return backgrounds[row * size.width + column]
    }

    mutating func fillBackground(_ color: Color, column: Int, row: Int) {
        hideImages(column: column, row: row, width: 1)
        backgrounds[row * size.width + column] = color
    }

    mutating func put(
        _ character: Character, width: Int, column: Int, row: Int, focused: Bool = false,
        foreground: Color? = nil, background: Color? = nil
    ) {
        hideImages(column: column, row: row, width: width)
        for column in column..<(column + width) { eraseGlyph(column: column, row: row) }
        let index = row * size.width + column
        cells[index] = character == " " ? .blank : .glyph(character, width: width)
        focusedCells[index] = focused
        foregrounds[index] = foreground
        backgrounds[index] = background
        if width == 2 {
            cells[index + 1] = .continuation
            focusedCells[index + 1] = focused
            foregrounds[index + 1] = foreground
            backgrounds[index + 1] = background
        }
    }

    private mutating func hideImages(column: Int, row: Int, width: Int) {
        guard !images.isEmpty else { return }
        let cell = CellRect(column: column, row: row, width: width, height: 1)
        images.removeAll {
            let overlap = $0.bounds.intersection(cell)
            return overlap.width > 0 && overlap.height > 0
        }
    }

    private mutating func eraseGlyph(column: Int, row: Int) {
        let index = row * size.width + column
        switch cells[index] {
        case .continuation:
            cells[index - 1] = .blank
            focusedCells[index - 1] = false
            foregrounds[index - 1] = nil
            backgrounds[index - 1] = nil
        case .glyph(_, width: 2):
            cells[index + 1] = .blank
            focusedCells[index + 1] = false
            foregrounds[index + 1] = nil
            backgrounds[index + 1] = nil
        default:
            break
        }
        cells[index] = .blank
        focusedCells[index] = false
        foregrounds[index] = nil
        backgrounds[index] = nil
    }
}

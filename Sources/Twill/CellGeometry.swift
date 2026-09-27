struct CellSize: Equatable, Sendable {
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        precondition(width >= 0 && height >= 0, "Cell dimensions must not be negative")
        self.width = width
        self.height = height
    }

    static let zero = CellSize(width: 0, height: 0)
}

struct ProposedCellSize {
    let width: Int?
    let height: Int?

    init(width: Int? = nil, height: Int? = nil) {
        precondition((width ?? 0) >= 0 && (height ?? 0) >= 0, "Proposed dimensions must not be negative")
        self.width = width
        self.height = height
    }

    static let unspecified = ProposedCellSize()

    func constrain(_ size: CellSize) -> CellSize {
        CellSize(width: min(width ?? size.width, size.width), height: min(height ?? size.height, size.height))
    }
}

struct CellRect: Equatable {
    let column: Int
    let row: Int
    let width: Int
    let height: Int

    init(column: Int, row: Int, width: Int, height: Int) {
        precondition(width >= 0 && height >= 0, "Cell dimensions must not be negative")
        self.column = column
        self.row = row
        self.width = width
        self.height = height
    }

    func intersection(_ other: CellRect) -> CellRect {
        let left = max(column, other.column)
        let top = max(row, other.row)
        return CellRect(
            column: left, row: top,
            width: max(0, min(column + width, other.column + other.width) - left),
            height: max(0, min(row + height, other.row + other.height) - top)
        )
    }
}

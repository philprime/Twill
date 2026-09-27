/// Child contexts share one frame while translating coordinates and narrowing the clip.
struct DrawingContext {
    private(set) var grid: CellGrid
    private var originX = 0
    private var originY = 0
    private var clip: CellRect
    private var focused = false

    init(size: CellSize) {
        grid = CellGrid(size: size)
        clip = CellRect(column: 0, row: 0, width: size.width, height: size.height)
    }

    mutating func withRegion(_ region: CellRect, draw: (inout DrawingContext) -> Void) {
        let previousX = originX
        let previousY = originY
        let previousClip = clip
        originX += region.column
        originY += region.row
        clip = clip.intersection(CellRect(column: originX, row: originY, width: region.width, height: region.height))
        draw(&self)
        originX = previousX
        originY = previousY
        clip = previousClip
    }

    mutating func withFocus(_ active: Bool, draw: (inout DrawingContext) -> Void) {
        let previous = focused
        focused = active
        draw(&self)
        focused = previous
    }

    mutating func draw(_ character: Character, width: Int, column: Int, row: Int) {
        let column = originX + column
        let row = originY + row
        guard column >= clip.column, column + width <= clip.column + clip.width,
            row >= clip.row, row < clip.row + clip.height
        else { return }
        grid.put(character, width: width, column: column, row: row, focused: focused)
    }
}

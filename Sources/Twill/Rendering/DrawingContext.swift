import Foundation

/// Child contexts share one frame while translating coordinates and narrowing the clip.
struct DrawingContext {
    private(set) var grid: CellGrid
    private(set) var caret: CellPosition?
    private(set) var regionSize: CellSize
    private var originX = 0
    private var originY = 0
    private var clip: CellRect
    private var focused = false
    private var foreground: Color?
    private var background: Color?

    init(size: CellSize) {
        grid = CellGrid(size: size)
        regionSize = size
        clip = CellRect(column: 0, row: 0, width: size.width, height: size.height)
    }

    mutating func withRegion(_ region: CellRect, draw: (inout DrawingContext) -> Void) {
        let previousX = originX
        let previousY = originY
        let previousClip = clip
        let previousSize = regionSize
        regionSize = CellSize(width: region.width, height: region.height)
        originX += region.column
        originY += region.row
        clip = clip.intersection(CellRect(column: originX, row: originY, width: region.width, height: region.height))
        draw(&self)
        originX = previousX
        originY = previousY
        clip = previousClip
        regionSize = previousSize
    }

    mutating func withStyle(
        foreground: Color?, background: Color?, size: CellSize, draw: (inout DrawingContext) -> Void
    ) {
        let oldForeground = self.foreground
        let oldBackground = self.background
        self.foreground = foreground ?? oldForeground
        self.background = background ?? oldBackground
        if let background {
            let area = clip.intersection(
                CellRect(column: originX, row: originY, width: size.width, height: size.height))
            for row in area.row..<(area.row + area.height) {
                for column in area.column..<(area.column + area.width) {
                    grid.fillBackground(background, column: column, row: row)
                }
            }
        }
        draw(&self)
        self.foreground = oldForeground
        self.background = oldBackground
    }

    mutating func withFocus(_ active: Bool, draw: (inout DrawingContext) -> Void) {
        let previous = focused
        focused = active
        draw(&self)
        focused = previous
    }

    mutating func placeCaret(column: Int, row: Int) {
        let position = CellPosition(column: originX + column, row: originY + row)
        guard position.column >= clip.column, position.column <= clip.column + clip.width,
            position.row >= clip.row, position.row < clip.row + clip.height
        else { return }
        caret = position
    }

    mutating func drawImage(_ data: Data, size: CellSize) {
        let bounds = CellRect(column: originX, row: originY, width: size.width, height: size.height)
        // Partial placements are omitted rather than rescaled into the clip. Cropping
        // requires pixel-to-cell metrics that this cell-only renderer does not own.
        guard size.width > 0, size.height > 0, clip.intersection(bounds) == bounds else { return }
        grid.images.append(ImagePlacement(data: data, bounds: bounds))
    }

    mutating func draw(
        _ character: Character, width: Int, column: Int, row: Int,
        foreground cellForeground: Color? = nil, background cellBackground: Color? = nil
    ) {
        let column = originX + column
        let row = originY + row
        guard column >= clip.column, column + width <= clip.column + clip.width,
            row >= clip.row, row < clip.row + clip.height
        else { return }
        grid.put(
            character, width: width, column: column, row: row, focused: focused,
            foreground: cellForeground ?? foreground,
            background: cellBackground ?? background ?? grid.background(column: column, row: row))
    }
}

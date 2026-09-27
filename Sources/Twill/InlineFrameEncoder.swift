/// Encodes the current single-row primitives without taking ownership of the shell's
/// whole screen. Layout/drawing use grids independently of this presentation policy.
enum InlineFrameEncoder {
    private static let clearLine = "\r\u{1B}[2K"

    static func encode(_ next: CellGrid?, previous: CellGrid?, invalidate: Bool = false) -> String {
        guard let next else { return previous == nil ? "" : clearLine }
        precondition(next.size.height <= 1, "Inline presentation requires a single row")
        if previous == nil || invalidate {
            return clearLine + text(next, columns: 0..<next.size.width)
        }
        let width = max(next.size.width, previous?.size.width ?? 0)
        var output = ""
        var column = 0
        while column < width {
            guard changed(next, previous: previous, column: column) else {
                column += 1
                continue
            }
            let start = column
            repeat { column += 1 } while column < width && changed(next, previous: previous, column: column)
            // A wide glyph is atomic even if only one of its cells differed.
            let lower = next[start, 0] == .continuation ? start - 1 : start
            let upper = next[column, 0] == .continuation ? column + 1 : column
            output += "\r"
            if lower > 0 { output += "\u{1B}[\(lower)C" }
            output += text(next, columns: lower..<upper)
            column = upper
        }
        return output
    }

    private static func changed(_ next: CellGrid, previous: CellGrid?, column: Int) -> Bool {
        next[column, 0] != previous?[column, 0]
            || next.isFocused(column: column, row: 0) != (previous?.isFocused(column: column, row: 0) ?? false)
    }

    private static func text(_ grid: CellGrid, columns: Range<Int>) -> String {
        var result = ""
        var inverted = false
        for column in columns {
            let cell = grid[column, 0]
            if cell == .continuation { continue }
            let focused = grid.isFocused(column: column, row: 0)
            if focused != inverted {
                result += focused ? "\u{1B}[7m" : "\u{1B}[27m"
                inverted = focused
            }
            switch cell {
            case .blank: result += " "
            case .glyph(let character, _): result.append(character)
            case .continuation: break
            }
        }
        // Never leave a borrowed terminal in reverse-video mode between writes.
        if inverted { result += "\u{1B}[27m" }
        return result
    }
}

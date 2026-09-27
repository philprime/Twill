/// Encodes cell updates inline, leaving earlier shell output outside the frame intact.
/// Multi-row frames reserve space once and return to their top-left anchor after writes.
enum InlineFrameEncoder {
    private static let clearLine = "\r\u{1B}[2K"

    static func encode(_ next: CellGrid?, previous: CellGrid?, invalidate: Bool = false) -> String {
        if max(next?.size.height ?? 0, previous?.size.height ?? 0) > 1 {
            return encodeRows(next, previous: previous, invalidate: invalidate)
        }
        guard let next else { return previous == nil ? "" : clearLine }
        if previous == nil || invalidate {
            return clearLine + text(next, row: 0, columns: 0..<next.size.width)
        }
        return changedRuns(next, previous: previous, row: 0)
    }

    private static func encodeRows(_ next: CellGrid?, previous: CellGrid?, invalidate: Bool) -> String {
        let oldHeight = previous?.size.height ?? 0
        let newHeight = next?.size.height ?? 0
        let addedRows = max(0, newHeight - max(1, oldHeight))
        var output = ""
        if addedRows > 0 {
            // Reserve lines before drawing so a frame started at the terminal's
            // bottom edge can scroll into view without displacing a finished row.
            output = "\r"
            if oldHeight > 1 { output += "\u{1B}[\(oldHeight - 1)B" }
            output += String(repeating: "\r\n", count: addedRows)
            output += "\r\u{1B}[\(newHeight - 1)A"
        }

        let redraw = invalidate || previous == nil || addedRows > 0
        var currentRow = 0
        for row in 0..<max(oldHeight, newHeight) {
            let encoded: String
            if let next, row < newHeight {
                encoded =
                    redraw || row >= oldHeight
                    ? clearLine + text(next, row: row, columns: 0..<next.size.width)
                    : changedRuns(next, previous: previous, row: row)
            } else {
                encoded = clearLine
            }
            guard !encoded.isEmpty else { continue }
            if row > currentRow { output += "\r\u{1B}[\(row - currentRow)B" }
            output += encoded
            currentRow = row
        }
        if currentRow > 0 { output += "\r\u{1B}[\(currentRow)A" } else if !output.isEmpty { output += "\r" }
        return output
    }

    private static func changedRuns(_ next: CellGrid, previous: CellGrid?, row: Int) -> String {
        let width = max(next.size.width, previous?.size.width ?? 0)
        var output = ""
        var column = 0
        while column < width {
            guard changed(next, previous: previous, column: column, row: row) else {
                column += 1
                continue
            }
            let start = column
            repeat { column += 1 } while column < width && changed(next, previous: previous, column: column, row: row)
            // A wide glyph is atomic even if only one of its cells differed.
            let lower = next[start, row] == .continuation ? start - 1 : start
            let upper = next[column, row] == .continuation ? column + 1 : column
            output += "\r"
            if lower > 0 { output += "\u{1B}[\(lower)C" }
            output += text(next, row: row, columns: lower..<upper)
            column = upper
        }
        return output
    }

    private static func changed(_ next: CellGrid, previous: CellGrid?, column: Int, row: Int) -> Bool {
        next[column, row] != previous?[column, row]
            || next.isFocused(column: column, row: row) != (previous?.isFocused(column: column, row: row) ?? false)
    }

    private static func text(_ grid: CellGrid, row: Int, columns: Range<Int>) -> String {
        var result = ""
        var inverted = false
        for column in columns {
            let cell = grid[column, row]
            if cell == .continuation { continue }
            let focused = grid.isFocused(column: column, row: row)
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

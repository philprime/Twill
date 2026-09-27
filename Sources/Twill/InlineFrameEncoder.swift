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
            guard next[column, 0] != previous?[column, 0] else {
                column += 1
                continue
            }
            let start = column
            repeat { column += 1 } while column < width && next[column, 0] != previous?[column, 0]
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

    private static func text(_ grid: CellGrid, columns: Range<Int>) -> String {
        var result = ""
        for column in columns {
            switch grid[column, 0] {
            case .blank: result += " "
            case .glyph(let character, _): result.append(character)
            case .continuation: break
            }
        }
        return result
    }
}

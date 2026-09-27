import Foundation

extension Canvas {
    /// The short-lived drawing surface for one presentation. Do not retain it after rendering.
    @MainActor
    public final class Context {
        public let date: Date
        var drawing: DrawingContext

        init(date: Date, drawing: DrawingContext) {
            self.date = date
            self.drawing = drawing
        }

        public func draw(
            _ character: Character, column: Int, row: Int,
            foreground: Color? = nil, background: Color? = nil
        ) {
            let first = character.unicodeScalars.first!
            let category = first.properties.generalCategory
            let safe: Character
            if category == .control || category == .format {
                safe = " "
            } else if category == .nonspacingMark || category == .enclosingMark || category == .spacingMark {
                safe = Character("◌" + String(character))
            } else {
                safe = character
            }
            drawing.draw(
                safe, width: TerminalCharacterWidth.columns(for: safe), column: column, row: row,
                foreground: foreground, background: background)
        }

        public func render(_ buffer: Canvas.Buffer, column: Int = 0, row: Int = 0) {
            for bufferRow in 0..<buffer.size.height {
                for bufferColumn in 0..<buffer.size.width {
                    guard let cell = buffer[bufferColumn, bufferRow] else { continue }
                    guard bufferColumn + TerminalCharacterWidth.columns(for: cell.character) <= buffer.size.width else {
                        continue
                    }
                    draw(
                        cell.character, column: column + bufferColumn, row: row + bufferRow,
                        foreground: cell.foreground, background: cell.background)
                }
            }
        }
    }
}

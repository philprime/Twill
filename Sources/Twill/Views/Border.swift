/// A terminal border pattern. Each variant occupies one cell on every side.
public enum Border: Sendable {
    /// The eight glyphs of a one-cell terminal border.
    public struct Glyphs: Sendable {
        public let topLeft: Character
        public let top: Character
        public let topRight: Character
        public let left: Character
        public let right: Character
        public let bottomLeft: Character
        public let bottom: Character
        public let bottomRight: Character

        public init(
            topLeft: Character, top: Character, topRight: Character,
            left: Character, right: Character,
            bottomLeft: Character, bottom: Character, bottomRight: Character
        ) {
            let glyphs = [topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight]
            precondition(
                glyphs.allSatisfy { glyph in
                    let firstCategory = glyph.unicodeScalars.first!.properties.generalCategory
                    return TerminalCharacterWidth.columns(for: glyph) == 1
                        && ![.nonspacingMark, .enclosingMark, .spacingMark].contains(firstCategory)
                        && glyph.unicodeScalars.allSatisfy {
                            $0.properties.generalCategory != .control && $0.properties.generalCategory != .format
                        }
                },
                "Border glyphs must be visible single-cell characters")
            self.topLeft = topLeft
            self.top = top
            self.topRight = topRight
            self.left = left
            self.right = right
            self.bottomLeft = bottomLeft
            self.bottom = bottom
            self.bottomRight = bottomRight
        }
    }

    case single
    case double
    case rounded
    case heavy
    case dashed
    case custom(Glyphs)

    var glyphs: Glyphs {
        switch self {
        case .single:
            Glyphs(
                topLeft: "┌", top: "─", topRight: "┐", left: "│", right: "│",
                bottomLeft: "└", bottom: "─", bottomRight: "┘")
        case .double:
            Glyphs(
                topLeft: "╔", top: "═", topRight: "╗", left: "║", right: "║",
                bottomLeft: "╚", bottom: "═", bottomRight: "╝")
        case .rounded:
            Glyphs(
                topLeft: "╭", top: "─", topRight: "╮", left: "│", right: "│",
                bottomLeft: "╰", bottom: "─", bottomRight: "╯")
        case .heavy:
            Glyphs(
                topLeft: "┏", top: "━", topRight: "┓", left: "┃", right: "┃",
                bottomLeft: "┗", bottom: "━", bottomRight: "┛")
        case .dashed:
            Glyphs(
                topLeft: "┌", top: "┄", topRight: "┐", left: "┆", right: "┆",
                bottomLeft: "└", bottom: "┄", bottomRight: "┘")
        case .custom(let glyphs): glyphs
        }
    }
}

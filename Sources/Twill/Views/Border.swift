/// A terminal border pattern. Each variant occupies one cell on every side.
public enum Border: Sendable {
    /// The eight glyphs of a one-cell terminal border.
    public struct Glyphs: Sendable {
        /// The character drawn at the upper leading corner.
        public let topLeft: Character
        /// The character repeated along the top edge.
        public let top: Character
        /// The character drawn at the upper trailing corner.
        public let topRight: Character
        /// The character repeated along the leading edge.
        public let left: Character
        /// The character repeated along the trailing edge.
        public let right: Character
        /// The character drawn at the lower leading corner.
        public let bottomLeft: Character
        /// The character repeated along the bottom edge.
        public let bottom: Character
        /// The character drawn at the lower trailing corner.
        public let bottomRight: Character

        /// Creates border glyphs. Each character must be visible and occupy exactly one terminal cell.
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

    /// Thin single-line edges and square corners.
    case single
    /// Double-line edges and corners.
    case double
    /// Thin single-line edges with rounded corners.
    case rounded
    /// Heavy single-line edges and square corners.
    case heavy
    /// Dashed thin edges with square corners.
    case dashed
    /// A border using caller-supplied, validated glyphs.
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

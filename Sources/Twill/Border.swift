/// The eight glyphs of a one-cell terminal border.
public struct BorderGlyphs: Sendable {
    public let topLeft: Character
    public let top: Character
    public let topRight: Character
    public let left: Character
    public let right: Character
    public let bottomLeft: Character
    public let bottom: Character
    public let bottomRight: Character

    public init(
        topLeft: Character, top: Character, topRight: Character, left: Character, right: Character,
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

/// A terminal border pattern. Each variant occupies one cell on every side.
public enum Border: Sendable {
    case single
    case double
    case thick
    case custom(BorderGlyphs)

    var glyphs: BorderGlyphs {
        switch self {
        case .single:
            BorderGlyphs(
                topLeft: "┌", top: "─", topRight: "┐", left: "│", right: "│",
                bottomLeft: "└", bottom: "─", bottomRight: "┘")
        case .double:
            BorderGlyphs(
                topLeft: "╔", top: "═", topRight: "╗", left: "║", right: "║",
                bottomLeft: "╚", bottom: "═", bottomRight: "╝")
        case .thick:
            BorderGlyphs(
                topLeft: "▐", top: "▀", topRight: "▌", left: "▐", right: "▌",
                bottomLeft: "▐", bottom: "▄", bottomRight: "▌")
        case .custom(let glyphs): glyphs
        }
    }
}

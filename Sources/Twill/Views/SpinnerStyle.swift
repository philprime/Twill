/// A single-cell animation pattern for indeterminate progress.
public enum SpinnerStyle: Sendable {
    /// A nonempty sequence of visible, single-cell animation frames.
    public struct Frames: Sendable {
        public let characters: [Character]

        public init(_ characters: [Character]) {
            precondition(
                !characters.isEmpty
                    && characters.allSatisfy { character in
                        let firstCategory = character.unicodeScalars.first!.properties.generalCategory
                        return TerminalCharacterWidth.columns(for: character) == 1
                            && ![.nonspacingMark, .enclosingMark, .spacingMark].contains(firstCategory)
                            && character.unicodeScalars.allSatisfy {
                                $0.properties.generalCategory != .control && $0.properties.generalCategory != .format
                            }
                    },
                "Spinner frames must be a nonempty sequence of visible single-cell characters")
            self.characters = characters
        }
    }

    /// Rotating Braille dots, the default spinner pattern.
    case dots
    /// A rotating quarter-circle arc.
    case arc
    /// A rotating ASCII line for terminals with limited glyph support.
    case line
    case custom(Frames)

    var frames: [Character] {
        switch self {
        case .dots: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        case .arc: ["◜", "◝", "◞", "◟"]
        case .line: ["|", "/", "-", "\\"]
        case .custom(let frames): frames.characters
        }
    }
}

extension Canvas {
    /// One terminal grapheme with optional per-cell colors.
    public struct Cell: Equatable {
        /// The character to draw at this cell.
        public let character: Character
        /// The foreground color, or nil to use the drawing context's inherited style.
        public let foreground: Color?
        /// The background color, or nil to use the drawing context's inherited style.
        public let background: Color?

        /// Creates a character cell with optional foreground and background colors.
        public init(_ character: Character, foreground: Color? = nil, background: Color? = nil) {
            self.character = character
            self.foreground = foreground
            self.background = background
        }
    }
}

extension Canvas {
    /// One terminal grapheme with optional per-cell colors.
    public struct Cell: Equatable {
        public let character: Character
        public let foreground: Color?
        public let background: Color?

        public init(_ character: Character, foreground: Color? = nil, background: Color? = nil) {
            self.character = character
            self.foreground = foreground
            self.background = background
        }
    }
}

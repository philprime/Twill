extension Canvas {
    /// A drawable extent measured in terminal columns and rows.
    public struct Size: Equatable, Sendable {
        /// The number of terminal columns available for drawing.
        public let width: Int
        /// The number of terminal rows available for drawing.
        public let height: Int

        /// Creates terminal-cell dimensions. Width and height must both be nonnegative.
        public init(width: Int, height: Int) {
            precondition(width >= 0 && height >= 0, "Canvas dimensions must not be negative")
            self.width = width
            self.height = height
        }
    }
}

extension Canvas {
    /// A drawable extent measured in terminal columns and rows.
    public struct Size: Equatable, Sendable {
        public let width: Int
        public let height: Int

        public init(width: Int, height: Int) {
            precondition(width >= 0 && height >= 0, "Canvas dimensions must not be negative")
            self.width = width
            self.height = height
        }
    }
}

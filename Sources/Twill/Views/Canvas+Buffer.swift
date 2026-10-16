extension Canvas {
    /// Sparse image: nil cells leave the canvas background untouched when copied.
    public struct Buffer {
        /// The fixed dimensions of the buffer in terminal cells.
        public let size: Canvas.Size
        private var cells: [Canvas.Cell?]

        /// Creates an empty buffer of the specified size, with every cell unset.
        public init(size: Canvas.Size) {
            self.size = size
            cells = Array(repeating: nil, count: size.width * size.height)
        }

        /// Reads or replaces a cell at zero-based coordinates. Both coordinates must be within `size`.
        public subscript(column: Int, row: Int) -> Canvas.Cell? {
            get {
                precondition(column >= 0 && column < size.width && row >= 0 && row < size.height)
                return cells[row * size.width + column]
            }
            set {
                precondition(column >= 0 && column < size.width && row >= 0 && row < size.height)
                cells[row * size.width + column] = newValue
            }
        }
    }
}

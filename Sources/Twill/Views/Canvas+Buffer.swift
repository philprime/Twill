extension Canvas {
    /// Sparse image: nil cells leave the canvas background untouched when copied.
    public struct Buffer {
        public let size: Canvas.Size
        private var cells: [Canvas.Cell?]

        public init(size: Canvas.Size) {
            self.size = size
            cells = Array(repeating: nil, count: size.width * size.height)
        }

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

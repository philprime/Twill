/// Describes a column's size in terminal cells.
public struct GridItem: Equatable, Sendable {
    /// The strategy used to allocate a grid column’s width.
    public enum Size: Equatable, Sendable {
        /// Reserves an exact nonnegative width, clipped by the viewport if necessary.
        case fixed(Int)
        /// Shares available width with other flexible columns within the given bounds.
        case flexible(minimum: Int = 1, maximum: Int = .max)
        /// Repeats columns of at least this width to fit the available space.
        case adaptive(minimum: Int)
    }

    /// The column sizing strategy.
    public let size: Size

    /// Creates a column description with nonnegative fixed/flexible widths and
    /// ordered flexible bounds. Adaptive minimums must be positive.
    public init(_ size: Size) {
        switch size {
        case .fixed(let width):
            precondition(width >= 0, "Fixed grid width must not be negative")
        case .flexible(let minimum, let maximum):
            precondition(minimum >= 0 && maximum >= minimum, "Grid column bounds must be nonnegative and ordered")
        case .adaptive(let minimum):
            precondition(minimum > 0, "Adaptive grid column minimum must be positive")
        }
        self.size = size
    }
}

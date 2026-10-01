/// Describes a column's size in terminal cells.
public struct GridItem: Equatable, Sendable {
    public enum Size: Equatable, Sendable {
        /// Shares available width with other flexible columns within the given bounds.
        case flexible(minimum: Int = 1, maximum: Int = .max)
        /// Repeats columns of at least this width to fit the available space.
        case adaptive(minimum: Int)
    }

    public let size: Size

    public init(_ size: Size) {
        switch size {
        case .flexible(let minimum, let maximum):
            precondition(minimum > 0 && maximum >= minimum, "Grid column bounds must be positive and ordered")
        case .adaptive(let minimum):
            precondition(minimum > 0, "Adaptive grid column minimum must be positive")
        }
        self.size = size
    }
}

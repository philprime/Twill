/// Describes a column's size in terminal cells.
public struct GridItem: Equatable, Sendable {
    public enum Size: Equatable, Sendable {
        /// Shares available width with other flexible columns within the given bounds.
        case flexible(minimum: Int = 1, maximum: Int = .max)
    }

    public let size: Size

    public init(_ size: Size) {
        if case .flexible(let minimum, let maximum) = size {
            precondition(minimum > 0 && maximum >= minimum, "Grid column bounds must be positive and ordered")
        }
        self.size = size
    }
}

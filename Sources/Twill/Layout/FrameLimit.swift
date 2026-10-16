/// An upper frame dimension in terminal cells, or all space offered by the parent.
public enum FrameLimit: ExpressibleByIntegerLiteral, Sendable {
    /// Limits the frame dimension to the specified number of terminal cells.
    case cells(Int)
    /// Uses all space offered by the parent along this dimension.
    case infinity

    /// Creates a cell-based limit from an integer literal.
    public init(integerLiteral value: Int) {
        self = .cells(value)
    }
}

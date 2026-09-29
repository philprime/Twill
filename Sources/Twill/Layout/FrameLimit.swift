/// An upper frame dimension in terminal cells, or all space offered by the parent.
public enum FrameLimit: ExpressibleByIntegerLiteral, Sendable {
    case cells(Int)
    case infinity

    public init(integerLiteral value: Int) {
        self = .cells(value)
    }
}

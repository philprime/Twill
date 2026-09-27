/// The visible terminal viewport, measured in character cells.
public struct TerminalSize: Equatable, Sendable {
    public let columns: Int
    public let rows: Int

    public init(columns: Int, rows: Int) {
        precondition(columns > 0 && rows > 0, "Terminal dimensions must be positive")
        self.columns = columns
        self.rows = rows
    }
}

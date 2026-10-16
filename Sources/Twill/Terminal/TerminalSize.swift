/// The visible terminal viewport, measured in character cells.
public struct TerminalSize: Equatable, Sendable {
    /// The number of visible character-cell columns.
    public let columns: Int
    /// The number of visible character-cell rows.
    public let rows: Int

    /// Creates a viewport size; both dimensions must be positive.
    public init(columns: Int, rows: Int) {
        precondition(columns > 0 && rows > 0, "Terminal dimensions must be positive")
        self.columns = columns
        self.rows = rows
    }
}

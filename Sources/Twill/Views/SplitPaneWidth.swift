/// Horizontal cell allocation for one split pane.
public enum SplitPaneWidth: Sendable {
    /// Reserves an exact nonnegative width.
    case fixed(Int)
    /// Shares surplus after reserving a nonnegative minimum.
    case flexible(minimum: Int = 0)

    var column: GridItem {
        switch self {
        case .fixed(let width): GridItem(.fixed(width))
        case .flexible(let minimum): GridItem(.flexible(minimum: minimum))
        }
    }
}

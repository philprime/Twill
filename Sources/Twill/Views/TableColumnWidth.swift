/// Terminal-cell sizing shared by a table column's header and body.
public enum TableColumnWidth: Sendable {
    /// Preserves intrinsic content and shares surplus; shrinks when space is scarce.
    case automatic
    /// Reserves an exact nonnegative width, clipped by the viewport if necessary.
    case fixed(Int)
    /// Shares available space within hard nonnegative inclusive bounds.
    case flexible(minimum: Int = 0, maximum: Int = .max)
}

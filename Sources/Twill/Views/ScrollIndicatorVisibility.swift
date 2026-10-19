/// Whether vertical scroll viewports reserve and draw a terminal-cell indicator.
public enum ScrollIndicatorVisibility: Equatable, Sendable {
    /// Reserves no indicator space, preserving the full content width.
    case hidden
    /// Reserves one right-hand column regardless of overflow and draws a track/thumb.
    case visible

    static let columnWidth = 1
    var reservedColumns: Int { self == .visible ? Self.columnWidth : 0 }
}

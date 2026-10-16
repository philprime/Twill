/// Horizontal placement of children within a vertical stack.
public enum HorizontalAlignment: Sendable {
    /// Aligns children to the leading edge.
    case leading
    /// Centers children horizontally.
    case center
    /// Aligns children to the trailing edge.
    case trailing
}

/// Vertical placement of children within a horizontal stack.
public enum VerticalAlignment: Sendable {
    /// Aligns children to the top edge.
    case top
    /// Centers children vertically.
    case center
    /// Aligns children to the bottom edge.
    case bottom
}

/// Placement of a view inside the space allocated by a frame.
public struct Alignment: Sendable {
    /// The horizontal placement within the allocated frame.
    public let horizontal: HorizontalAlignment
    /// The vertical placement within the allocated frame.
    public let vertical: VerticalAlignment

    /// Creates a placement from independent horizontal and vertical alignments.
    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// Centers the view on both axes.
    public static let center = Alignment(horizontal: .center, vertical: .center)
    /// Places the view at the leading edge, centered vertically.
    public static let leading = Alignment(horizontal: .leading, vertical: .center)
    /// Places the view at the trailing edge, centered vertically.
    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
    /// Places the view at the top edge, centered horizontally.
    public static let top = Alignment(horizontal: .center, vertical: .top)
    /// Places the view at the bottom edge, centered horizontally.
    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
    /// Places the view at the top leading corner.
    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
    /// Places the view at the top trailing corner.
    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
    /// Places the view at the bottom leading corner.
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
    /// Places the view at the bottom trailing corner.
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}

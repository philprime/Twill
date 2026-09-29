/// Horizontal placement of children within a vertical stack.
public enum HorizontalAlignment: Sendable {
    case leading
    case center
    case trailing
}

/// Vertical placement of children within a horizontal stack.
public enum VerticalAlignment: Sendable {
    case top
    case center
    case bottom
}

/// Placement of a view inside the space allocated by a frame.
public struct Alignment: Sendable {
    public let horizontal: HorizontalAlignment
    public let vertical: VerticalAlignment

    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public static let center = Alignment(horizontal: .center, vertical: .center)
    public static let leading = Alignment(horizontal: .leading, vertical: .center)
    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
    public static let top = Alignment(horizontal: .center, vertical: .top)
    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)
}

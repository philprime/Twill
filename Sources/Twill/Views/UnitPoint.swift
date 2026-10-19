/// A normalized position within a rectangle, independent of its size.
/// Coordinates increase rightward and downward. Values outside zero through one
/// select points outside the rectangle.
public struct UnitPoint: Sendable, Equatable {
    /// The fraction of the rectangle's width.
    public let horizontal: Double
    /// The fraction of the rectangle's height.
    public let vertical: Double

    /// Creates an anchor with finite normalized coordinates.
    public init(x horizontal: Double, y vertical: Double) {
        precondition(horizontal.isFinite && vertical.isFinite)
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// The top-left corner.
    public static let topLeading = Self(x: 0, y: 0)
    /// The midpoint of the top edge.
    public static let top = Self(x: 0.5, y: 0)
    /// The top-right corner.
    public static let topTrailing = Self(x: 1, y: 0)
    /// The midpoint of the left edge.
    public static let leading = Self(x: 0, y: 0.5)
    /// The center of the rectangle.
    public static let center = Self(x: 0.5, y: 0.5)
    /// The midpoint of the right edge.
    public static let trailing = Self(x: 1, y: 0.5)
    /// The bottom-left corner.
    public static let bottomLeading = Self(x: 0, y: 1)
    /// The midpoint of the bottom edge.
    public static let bottom = Self(x: 0.5, y: 1)
    /// The bottom-right corner.
    public static let bottomTrailing = Self(x: 1, y: 1)
}

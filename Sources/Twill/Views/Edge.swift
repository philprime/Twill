/// An edge of a view in terminal cell coordinates.
public enum Edge: Sendable {
    /// The upper horizontal edge.
    case top
    /// The leading vertical edge.
    case leading
    /// The lower horizontal edge.
    case bottom
    /// The trailing vertical edge.
    case trailing

    /// A combinable collection of edges for operations such as padding.
    public struct Set: OptionSet, Sendable {
        /// The bit mask representing the included edges.
        public let rawValue: Int

        /// Creates an edge set from its underlying bit mask.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Includes the upper edge.
        public static let top = Set(rawValue: 1 << 0)
        /// Includes the leading edge.
        public static let leading = Set(rawValue: 1 << 1)
        /// Includes the lower edge.
        public static let bottom = Set(rawValue: 1 << 2)
        /// Includes the trailing edge.
        public static let trailing = Set(rawValue: 1 << 3)
        /// Includes both leading and trailing edges.
        public static let horizontal: Set = [.leading, .trailing]
        /// Includes both top and bottom edges.
        public static let vertical: Set = [.top, .bottom]
        /// Includes all four edges.
        public static let all: Set = [.horizontal, .vertical]
    }
}

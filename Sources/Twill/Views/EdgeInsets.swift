/// Cell counts around the edges of a view.
public struct EdgeInsets: Equatable, Sendable {
    /// The number of blank rows above the content.
    public let top: Int
    /// The number of blank columns before the content.
    public let leading: Int
    /// The number of blank rows below the content.
    public let bottom: Int
    /// The number of blank columns after the content.
    public let trailing: Int

    /// Creates per-edge terminal-cell insets. Every inset must be nonnegative.
    public init(top: Int, leading: Int, bottom: Int, trailing: Int) {
        precondition(top >= 0 && leading >= 0 && bottom >= 0 && trailing >= 0, "Insets must not be negative")
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

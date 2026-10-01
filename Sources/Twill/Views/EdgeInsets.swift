/// Cell counts around the edges of a view.
public struct EdgeInsets: Equatable, Sendable {
    public let top: Int
    public let leading: Int
    public let bottom: Int
    public let trailing: Int

    public init(top: Int, leading: Int, bottom: Int, trailing: Int) {
        precondition(top >= 0 && leading >= 0 && bottom >= 0 && trailing >= 0, "Insets must not be negative")
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

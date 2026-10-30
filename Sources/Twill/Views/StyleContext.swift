/// Presentation values available to a style without exposing mounted views or application state.
public struct StyleContext: Sendable {
    /// The primary foreground style inherited from the containing content.
    public let foreground: ResolvedStyle
    /// The nearest control-tint override, or nil for the inherited foreground color.
    public let tint: Color?

    /// Creates an immutable context for resolving a terminal style.
    public init(foreground: ResolvedStyle = ResolvedStyle(color: nil), tint: Color? = nil) {
        self.foreground = foreground
        self.tint = tint
    }
}

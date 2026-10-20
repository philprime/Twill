/// Concrete colors for semantic roles. Nil selects the terminal's default color.
/// A theme boundary replaces the palette without painting or changing layout.
public struct Theme: Equatable, Sendable {
    /// The normal text color, or terminal default.
    public let foreground: Color?
    /// The normal surface color, or terminal default.
    public let background: Color?
    /// The highlighted-action color.
    public let accent: Color?
    /// The secondary-content color.
    public let muted: Color?
    /// The validation/destructive-action color.
    public let validation: Color?

    /// Creates a palette. Foreground/background use terminal defaults unless supplied.
    public init(
        foreground: Color? = nil, background: Color? = nil, accent: Color? = .cyan,
        muted: Color? = .brightBlack, validation: Color? = .red
    ) {
        self.foreground = foreground
        self.background = background
        self.accent = accent
        self.muted = muted
        self.validation = validation
    }
}

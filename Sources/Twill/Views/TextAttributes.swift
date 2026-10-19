/// Terminal presentation flags, independent of foreground/background and focus.
public struct TextAttributes: OptionSet, Hashable, Sendable {
    /// The bit mask containing the enabled flags.
    public let rawValue: UInt8

    /// Creates flags from their raw bit mask.
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// Requests increased text intensity.
    public static let bold = Self(rawValue: 1 << 0)
    /// Requests reduced text intensity.
    public static let dim = Self(rawValue: 1 << 1)
    /// Requests italic glyphs, when supported by the terminal.
    public static let italic = Self(rawValue: 1 << 2)
    /// Requests an underline.
    public static let underline = Self(rawValue: 1 << 3)

    static let supported: Self = [.bold, .dim, .italic, .underline]
    static let intensity: Self = [.bold, .dim]
}

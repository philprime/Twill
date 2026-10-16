/// Modifier flags reported separately from a decoded key’s identity.
public struct KeyModifiers: OptionSet, Sendable, Equatable {
    /// The bit mask containing the reported modifier flags.
    public let rawValue: UInt8

    /// Creates modifier flags from their raw bit mask.
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// The Shift modifier.
    public static let shift = Self(rawValue: 1 << 0)
    /// The Alt modifier, commonly labeled Option on Apple keyboards.
    public static let alt = Self(rawValue: 1 << 1)
    /// The Control modifier, distinct from a raw control-byte key event.
    public static let control = Self(rawValue: 1 << 2)
    /// The Super modifier.
    public static let superKey = Self(rawValue: 1 << 3)
    /// The Hyper modifier.
    public static let hyper = Self(rawValue: 1 << 4)
    /// The Meta modifier.
    public static let meta = Self(rawValue: 1 << 5)
}

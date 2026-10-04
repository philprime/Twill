public struct KeyModifiers: OptionSet, Sendable, Equatable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let shift = Self(rawValue: 1 << 0)
    public static let alt = Self(rawValue: 1 << 1)
    public static let control = Self(rawValue: 1 << 2)
    public static let superKey = Self(rawValue: 1 << 3)
    public static let hyper = Self(rawValue: 1 << 4)
    public static let meta = Self(rawValue: 1 << 5)
}

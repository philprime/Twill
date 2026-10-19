/// Straight-alpha, eight-bit RGBA components independent of terminal palette colors.
public struct PixelColor: Sendable, Equatable {
    /// The red component.
    public let red: UInt8
    /// The green component.
    public let green: UInt8
    /// The blue component.
    public let blue: UInt8
    /// The opacity, from zero (transparent) through 255 (opaque).
    public let alpha: UInt8

    /// Creates a bitmap color, opaque by default.
    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Transparent black.
    public static let clear = Self(red: 0, green: 0, blue: 0, alpha: 0)
}

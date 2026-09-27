/// An RGB terminal color. Components use the range 0...255.
public struct Color: Equatable, Style {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public var color: Color { self }

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

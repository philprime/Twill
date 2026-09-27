/// A terminal color, either a true-color RGB value or a theme-dependent ANSI palette entry.
public enum Color: Equatable, Style {
    case rgb(red: UInt8, green: UInt8, blue: UInt8)
    case ansi(ANSIColor)

    public enum ANSIColor: Int, Sendable {
        case black, red, green, yellow, blue, magenta, cyan, white
        case brightBlack, brightRed, brightGreen, brightYellow
        case brightBlue, brightMagenta, brightCyan, brightWhite
    }

    public var color: Color { self }

    public static let black = Color.ansi(.black)
    public static let red = Color.ansi(.red)
    public static let green = Color.ansi(.green)
    public static let yellow = Color.ansi(.yellow)
    public static let blue = Color.ansi(.blue)
    public static let magenta = Color.ansi(.magenta)
    public static let cyan = Color.ansi(.cyan)
    public static let white = Color.ansi(.white)

    public static let brightBlack = Color.ansi(.brightBlack)
    public static let brightRed = Color.ansi(.brightRed)
    public static let brightGreen = Color.ansi(.brightGreen)
    public static let brightYellow = Color.ansi(.brightYellow)
    public static let brightBlue = Color.ansi(.brightBlue)
    public static let brightMagenta = Color.ansi(.brightMagenta)
    public static let brightCyan = Color.ansi(.brightCyan)
    public static let brightWhite = Color.ansi(.brightWhite)

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self = .rgb(red: red, green: green, blue: blue)
    }
}

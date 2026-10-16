/// A terminal color, either a true-color RGB value or a theme-dependent ANSI palette entry.
public enum Color: Equatable, Style {
    /// A true-color value with red, green, and blue components from zero through 255.
    case rgb(red: UInt8, green: UInt8, blue: UInt8)
    /// A terminal palette entry whose displayed color depends on the terminal theme.
    case ansi(ANSIColor)

    /// The sixteen standard and bright terminal palette entries.
    public enum ANSIColor: Int, Sendable {
        /// The standard black terminal palette entry.
        case black
        /// The standard red terminal palette entry.
        case red
        /// The standard green terminal palette entry.
        case green
        /// The standard yellow terminal palette entry.
        case yellow
        /// The standard blue terminal palette entry.
        case blue
        /// The standard magenta terminal palette entry.
        case magenta
        /// The standard cyan terminal palette entry.
        case cyan
        /// The standard white terminal palette entry.
        case white
        /// The bright black terminal palette entry.
        case brightBlack
        /// The bright red terminal palette entry.
        case brightRed
        /// The bright green terminal palette entry.
        case brightGreen
        /// The bright yellow terminal palette entry.
        case brightYellow
        /// The bright blue terminal palette entry.
        case brightBlue
        /// The bright magenta terminal palette entry.
        case brightMagenta
        /// The bright cyan terminal palette entry.
        case brightCyan
        /// The bright white terminal palette entry.
        case brightWhite
    }

    /// This color itself, used when resolving the value as a style.
    public var color: Color { self }

    /// The theme-dependent ANSI black color.
    public static let black = Color.ansi(.black)
    /// The theme-dependent ANSI red color.
    public static let red = Color.ansi(.red)
    /// The theme-dependent ANSI green color.
    public static let green = Color.ansi(.green)
    /// The theme-dependent ANSI yellow color.
    public static let yellow = Color.ansi(.yellow)
    /// The theme-dependent ANSI blue color.
    public static let blue = Color.ansi(.blue)
    /// The theme-dependent ANSI magenta color.
    public static let magenta = Color.ansi(.magenta)
    /// The theme-dependent ANSI cyan color.
    public static let cyan = Color.ansi(.cyan)
    /// The theme-dependent ANSI white color.
    public static let white = Color.ansi(.white)

    /// The theme-dependent ANSI bright black color.
    public static let brightBlack = Color.ansi(.brightBlack)
    /// The theme-dependent ANSI bright red color.
    public static let brightRed = Color.ansi(.brightRed)
    /// The theme-dependent ANSI bright green color.
    public static let brightGreen = Color.ansi(.brightGreen)
    /// The theme-dependent ANSI bright yellow color.
    public static let brightYellow = Color.ansi(.brightYellow)
    /// The theme-dependent ANSI bright blue color.
    public static let brightBlue = Color.ansi(.brightBlue)
    /// The theme-dependent ANSI bright magenta color.
    public static let brightMagenta = Color.ansi(.brightMagenta)
    /// The theme-dependent ANSI bright cyan color.
    public static let brightCyan = Color.ansi(.brightCyan)
    /// The theme-dependent ANSI bright white color.
    public static let brightWhite = Color.ansi(.brightWhite)

    /// Creates a true-color value from eight-bit red, green, and blue components.
    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self = .rgb(red: red, green: green, blue: blue)
    }
}

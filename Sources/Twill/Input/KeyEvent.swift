// swift-format-ignore-file: AlwaysUseLowerCamelCase

/// A decoded key and its terminal-reported modifiers.
/// Text is delivered one Unicode scalar at a time, not as composed grapheme clusters.
public struct KeyEvent: Sendable, Equatable {
    /// The decoded character, special key, control byte, or unrecognized sequence.
    public enum Key: Sendable, Equatable {
        /// A text character; terminal input is decoded one Unicode scalar at a time.
        case character(Character)
        /// The Enter key, decoded from carriage return or line feed.
        case enter
        /// The Tab key; Shift-Tab uses the event’s shift modifier.
        case tab
        /// The Backspace key, decoded from backspace or DEL.
        case backspace
        /// The Escape key after disambiguation from an escape-sequence prefix.
        case escape
        /// The Up, Down, Left, and Right arrow keys.
        case arrowUp, arrowDown, arrowLeft, arrowRight
        /// The Home, End, Insert, forward Delete, Page Up, and Page Down keys.
        case home, end, insert, delete, pageUp, pageDown
        /// A function key identified by its number, such as 1 for F1.
        case function(Int)
        /// A raw control byte that was not decoded as a named special key.
        case control(UInt8)
        /// A complete, unrecognized CSI or SS3 sequence (including its Escape prefix).
        case unknown([UInt8])
    }

    /// The decoded key identity, separate from its reported modifiers.
    public let key: Key
    /// Modifier flags reported by the terminal; character case alone does not imply a shift flag.
    public let modifiers: KeyModifiers

    /// Creates an event with the given key identity and explicit modifier flags.
    public init(_ key: Key, modifiers: KeyModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Creates a character event without modifier flags, preserving the character’s case.
    public static func character(_ character: Character) -> Self { Self(.character(character)) }

    /// Creates a character event with explicit modifier flags.
    public static func character(_ character: Character, modifiers: KeyModifiers) -> Self {
        Self(.character(character), modifiers: modifiers)
    }

    /// Creates an event for a raw control byte without separate modifier flags.
    public static func control(_ byte: UInt8) -> Self { Self(.control(byte)) }
    /// Creates a numbered function-key event with optional modifier flags.
    public static func function(_ number: Int, modifiers: KeyModifiers = []) -> Self {
        Self(.function(number), modifiers: modifiers)
    }

    /// The Enter key without modifier flags.
    public static let enter = Self(.enter)
    /// The Tab key without modifier flags.
    public static let tab = Self(.tab)
    /// The Tab key with the shift modifier.
    public static let shiftTab = Self(.tab, modifiers: [.shift])
    /// The Backspace key without modifier flags.
    public static let backspace = Self(.backspace)
    /// The Escape key without modifier flags.
    public static let escape = Self(.escape)
    /// The Up Arrow key without modifier flags.
    public static let arrowUp = Self(.arrowUp)
    /// The Down Arrow key without modifier flags.
    public static let arrowDown = Self(.arrowDown)
    /// The Left Arrow key without modifier flags.
    public static let arrowLeft = Self(.arrowLeft)
    /// The Right Arrow key without modifier flags.
    public static let arrowRight = Self(.arrowRight)
    /// The Home key without modifier flags.
    public static let home = Self(.home)
    /// The End key without modifier flags.
    public static let end = Self(.end)
    /// The Insert key without modifier flags.
    public static let insert = Self(.insert)
    /// The forward Delete key without modifier flags.
    public static let delete = Self(.delete)
    /// The Page Up key without modifier flags.
    public static let pageUp = Self(.pageUp)
    /// The Page Down key without modifier flags.
    public static let pageDown = Self(.pageDown)

    /// Ctrl-C, usually used to request orderly shutdown.
    public static let controlC = Self.control(0x03)

    /// Ctrl-D, conventionally associated with end-of-input.
    public static let controlD = Self.control(0x04)
}

// Named values for printable ASCII. Other Unicode characters remain available through .character(_:).
extension KeyEvent {
    // Letter names mirror their character values, including case.
    // swiftlint:disable identifier_name
    /// The lowercase letter a, without modifier flags.
    public static let a = Self.character("a")
    /// The lowercase letter b, without modifier flags.
    public static let b = Self.character("b")
    /// The lowercase letter c, without modifier flags.
    public static let c = Self.character("c")
    /// The lowercase letter d, without modifier flags.
    public static let d = Self.character("d")
    /// The lowercase letter e, without modifier flags.
    public static let e = Self.character("e")
    /// The lowercase letter f, without modifier flags.
    public static let f = Self.character("f")
    /// The lowercase letter g, without modifier flags.
    public static let g = Self.character("g")
    /// The lowercase letter h, without modifier flags.
    public static let h = Self.character("h")
    /// The lowercase letter i, without modifier flags.
    public static let i = Self.character("i")
    /// The lowercase letter j, without modifier flags.
    public static let j = Self.character("j")
    /// The lowercase letter k, without modifier flags.
    public static let k = Self.character("k")
    /// The lowercase letter l, without modifier flags.
    public static let l = Self.character("l")
    /// The lowercase letter m, without modifier flags.
    public static let m = Self.character("m")
    /// The lowercase letter n, without modifier flags.
    public static let n = Self.character("n")
    /// The lowercase letter o, without modifier flags.
    public static let o = Self.character("o")
    /// The lowercase letter p, without modifier flags.
    public static let p = Self.character("p")
    /// The lowercase letter q, without modifier flags.
    public static let q = Self.character("q")
    /// The lowercase letter r, without modifier flags.
    public static let r = Self.character("r")
    /// The lowercase letter s, without modifier flags.
    public static let s = Self.character("s")
    /// The lowercase letter t, without modifier flags.
    public static let t = Self.character("t")
    /// The lowercase letter u, without modifier flags.
    public static let u = Self.character("u")
    /// The lowercase letter v, without modifier flags.
    public static let v = Self.character("v")
    /// The lowercase letter w, without modifier flags.
    public static let w = Self.character("w")
    /// The lowercase letter x, without modifier flags.
    public static let x = Self.character("x")
    /// The lowercase letter y, without modifier flags.
    public static let y = Self.character("y")
    /// The lowercase letter z, without modifier flags.
    public static let z = Self.character("z")

    /// The uppercase letter A, without modifier flags.
    public static let A = Self.character("A")
    /// The uppercase letter B, without modifier flags.
    public static let B = Self.character("B")
    /// The uppercase letter C, without modifier flags.
    public static let C = Self.character("C")
    /// The uppercase letter D, without modifier flags.
    public static let D = Self.character("D")
    /// The uppercase letter E, without modifier flags.
    public static let E = Self.character("E")
    /// The uppercase letter F, without modifier flags.
    public static let F = Self.character("F")
    /// The uppercase letter G, without modifier flags.
    public static let G = Self.character("G")
    /// The uppercase letter H, without modifier flags.
    public static let H = Self.character("H")
    /// The uppercase letter I, without modifier flags.
    public static let I = Self.character("I")
    /// The uppercase letter J, without modifier flags.
    public static let J = Self.character("J")
    /// The uppercase letter K, without modifier flags.
    public static let K = Self.character("K")
    /// The uppercase letter L, without modifier flags.
    public static let L = Self.character("L")
    /// The uppercase letter M, without modifier flags.
    public static let M = Self.character("M")
    /// The uppercase letter N, without modifier flags.
    public static let N = Self.character("N")
    /// The uppercase letter O, without modifier flags.
    public static let O = Self.character("O")
    /// The uppercase letter P, without modifier flags.
    public static let P = Self.character("P")
    /// The uppercase letter Q, without modifier flags.
    public static let Q = Self.character("Q")
    /// The uppercase letter R, without modifier flags.
    public static let R = Self.character("R")
    /// The uppercase letter S, without modifier flags.
    public static let S = Self.character("S")
    /// The uppercase letter T, without modifier flags.
    public static let T = Self.character("T")
    /// The uppercase letter U, without modifier flags.
    public static let U = Self.character("U")
    /// The uppercase letter V, without modifier flags.
    public static let V = Self.character("V")
    /// The uppercase letter W, without modifier flags.
    public static let W = Self.character("W")
    /// The uppercase letter X, without modifier flags.
    public static let X = Self.character("X")
    /// The uppercase letter Y, without modifier flags.
    public static let Y = Self.character("Y")
    /// The uppercase letter Z, without modifier flags.
    public static let Z = Self.character("Z")
    // swiftlint:enable identifier_name

    /// The digit 0, without modifier flags.
    public static let zero = Self.character("0")
    /// The digit 1, without modifier flags.
    public static let one = Self.character("1")
    /// The digit 2, without modifier flags.
    public static let two = Self.character("2")
    /// The digit 3, without modifier flags.
    public static let three = Self.character("3")
    /// The digit 4, without modifier flags.
    public static let four = Self.character("4")
    /// The digit 5, without modifier flags.
    public static let five = Self.character("5")
    /// The digit 6, without modifier flags.
    public static let six = Self.character("6")
    /// The digit 7, without modifier flags.
    public static let seven = Self.character("7")
    /// The digit 8, without modifier flags.
    public static let eight = Self.character("8")
    /// The digit 9, without modifier flags.
    public static let nine = Self.character("9")

    /// The space character ( ), without modifier flags.
    public static let space = Self.character(" ")
    /// The exclamation mark character (!), without modifier flags.
    public static let exclamationMark = Self.character("!")
    /// The double quotation mark character ("), without modifier flags.
    public static let doubleQuote = Self.character("\"")
    /// The number sign character (#), without modifier flags.
    public static let numberSign = Self.character("#")
    /// The dollar sign character ($), without modifier flags.
    public static let dollarSign = Self.character("$")
    /// The percent sign character (%), without modifier flags.
    public static let percentSign = Self.character("%")
    /// The ampersand character (&), without modifier flags.
    public static let ampersand = Self.character("&")
    /// The apostrophe character ('), without modifier flags.
    public static let apostrophe = Self.character("'")
    /// The left parenthesis character ((), without modifier flags.
    public static let leftParenthesis = Self.character("(")
    /// The right parenthesis character ()), without modifier flags.
    public static let rightParenthesis = Self.character(")")
    /// The asterisk character (*), without modifier flags.
    public static let asterisk = Self.character("*")
    /// The plus sign character (+), without modifier flags.
    public static let plus = Self.character("+")
    /// The comma character (,), without modifier flags.
    public static let comma = Self.character(",")
    /// The minus sign character (-), without modifier flags.
    public static let minus = Self.character("-")
    /// The period character (.), without modifier flags.
    public static let period = Self.character(".")
    /// The slash character (/), without modifier flags.
    public static let slash = Self.character("/")
    /// The colon character (:), without modifier flags.
    public static let colon = Self.character(":")
    /// The semicolon character (;), without modifier flags.
    public static let semicolon = Self.character(";")
    /// The less-than sign character (<), without modifier flags.
    public static let lessThan = Self.character("<")
    /// The equals sign character (=), without modifier flags.
    public static let equals = Self.character("=")
    /// The greater-than sign character (>), without modifier flags.
    public static let greaterThan = Self.character(">")
    /// The question mark character (?), without modifier flags.
    public static let questionMark = Self.character("?")
    /// The at sign character (@), without modifier flags.
    public static let atSign = Self.character("@")
    /// The left square bracket character ([), without modifier flags.
    public static let leftBracket = Self.character("[")
    /// The backslash character (\), without modifier flags.
    public static let backslash = Self.character("\\")
    /// The right square bracket character (]), without modifier flags.
    public static let rightBracket = Self.character("]")
    /// The caret character (^), without modifier flags.
    public static let caret = Self.character("^")
    /// The underscore character (_), without modifier flags.
    public static let underscore = Self.character("_")
    /// The grave accent character (`), without modifier flags.
    public static let graveAccent = Self.character("`")
    /// The left brace character ({), without modifier flags.
    public static let leftBrace = Self.character("{")
    /// The vertical bar character (|), without modifier flags.
    public static let pipe = Self.character("|")
    /// The right brace character (}), without modifier flags.
    public static let rightBrace = Self.character("}")
    /// The tilde character (~), without modifier flags.
    public static let tilde = Self.character("~")
}

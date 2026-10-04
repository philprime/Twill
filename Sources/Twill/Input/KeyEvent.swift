// swift-format-ignore-file: AlwaysUseLowerCamelCase

/// A decoded key and its terminal-reported modifiers.
/// Text is delivered one Unicode scalar at a time, not as composed grapheme clusters.
public struct KeyEvent: Sendable, Equatable {
    public enum Key: Sendable, Equatable {
        case character(Character)
        case enter
        case tab
        case backspace
        case escape
        case arrowUp, arrowDown, arrowLeft, arrowRight
        case home, end, insert, delete, pageUp, pageDown
        case function(Int)
        case control(UInt8)
        /// A complete, unrecognized CSI or SS3 sequence (including its Escape prefix).
        case unknown([UInt8])
    }

    public let key: Key
    public let modifiers: KeyModifiers

    public init(_ key: Key, modifiers: KeyModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    public static func character(_ character: Character) -> Self { Self(.character(character)) }

    public static func character(_ character: Character, modifiers: KeyModifiers) -> Self {
        Self(.character(character), modifiers: modifiers)
    }

    public static func control(_ byte: UInt8) -> Self { Self(.control(byte)) }
    public static func function(_ number: Int, modifiers: KeyModifiers = []) -> Self {
        Self(.function(number), modifiers: modifiers)
    }

    public static let enter = Self(.enter)
    public static let tab = Self(.tab)
    public static let shiftTab = Self(.tab, modifiers: [.shift])
    public static let backspace = Self(.backspace)
    public static let escape = Self(.escape)
    public static let arrowUp = Self(.arrowUp)
    public static let arrowDown = Self(.arrowDown)
    public static let arrowLeft = Self(.arrowLeft)
    public static let arrowRight = Self(.arrowRight)
    public static let home = Self(.home)
    public static let end = Self(.end)
    public static let insert = Self(.insert)
    public static let delete = Self(.delete)
    public static let pageUp = Self(.pageUp)
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
    public static let a = Self.character("a")
    public static let b = Self.character("b")
    public static let c = Self.character("c")
    public static let d = Self.character("d")
    public static let e = Self.character("e")
    public static let f = Self.character("f")
    public static let g = Self.character("g")
    public static let h = Self.character("h")
    public static let i = Self.character("i")
    public static let j = Self.character("j")
    public static let k = Self.character("k")
    public static let l = Self.character("l")
    public static let m = Self.character("m")
    public static let n = Self.character("n")
    public static let o = Self.character("o")
    public static let p = Self.character("p")
    public static let q = Self.character("q")
    public static let r = Self.character("r")
    public static let s = Self.character("s")
    public static let t = Self.character("t")
    public static let u = Self.character("u")
    public static let v = Self.character("v")
    public static let w = Self.character("w")
    public static let x = Self.character("x")
    public static let y = Self.character("y")
    public static let z = Self.character("z")

    public static let A = Self.character("A")
    public static let B = Self.character("B")
    public static let C = Self.character("C")
    public static let D = Self.character("D")
    public static let E = Self.character("E")
    public static let F = Self.character("F")
    public static let G = Self.character("G")
    public static let H = Self.character("H")
    public static let I = Self.character("I")
    public static let J = Self.character("J")
    public static let K = Self.character("K")
    public static let L = Self.character("L")
    public static let M = Self.character("M")
    public static let N = Self.character("N")
    public static let O = Self.character("O")
    public static let P = Self.character("P")
    public static let Q = Self.character("Q")
    public static let R = Self.character("R")
    public static let S = Self.character("S")
    public static let T = Self.character("T")
    public static let U = Self.character("U")
    public static let V = Self.character("V")
    public static let W = Self.character("W")
    public static let X = Self.character("X")
    public static let Y = Self.character("Y")
    public static let Z = Self.character("Z")
    // swiftlint:enable identifier_name

    public static let zero = Self.character("0")
    public static let one = Self.character("1")
    public static let two = Self.character("2")
    public static let three = Self.character("3")
    public static let four = Self.character("4")
    public static let five = Self.character("5")
    public static let six = Self.character("6")
    public static let seven = Self.character("7")
    public static let eight = Self.character("8")
    public static let nine = Self.character("9")

    public static let space = Self.character(" ")
    public static let exclamationMark = Self.character("!")
    public static let doubleQuote = Self.character("\"")
    public static let numberSign = Self.character("#")
    public static let dollarSign = Self.character("$")
    public static let percentSign = Self.character("%")
    public static let ampersand = Self.character("&")
    public static let apostrophe = Self.character("'")
    public static let leftParenthesis = Self.character("(")
    public static let rightParenthesis = Self.character(")")
    public static let asterisk = Self.character("*")
    public static let plus = Self.character("+")
    public static let comma = Self.character(",")
    public static let minus = Self.character("-")
    public static let period = Self.character(".")
    public static let slash = Self.character("/")
    public static let colon = Self.character(":")
    public static let semicolon = Self.character(";")
    public static let lessThan = Self.character("<")
    public static let equals = Self.character("=")
    public static let greaterThan = Self.character(">")
    public static let questionMark = Self.character("?")
    public static let atSign = Self.character("@")
    public static let leftBracket = Self.character("[")
    public static let backslash = Self.character("\\")
    public static let rightBracket = Self.character("]")
    public static let caret = Self.character("^")
    public static let underscore = Self.character("_")
    public static let graveAccent = Self.character("`")
    public static let leftBrace = Self.character("{")
    public static let pipe = Self.character("|")
    public static let rightBrace = Self.character("}")
    public static let tilde = Self.character("~")
}

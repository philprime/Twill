import Testing

@testable import Twill

@Suite("Named character keys")
struct KeyEventTests {
    @Test("Lowercase letter constants match character events")
    func lowercaseLetters() {
        // -- Arrange --
        let names: [KeyEvent] = [
            .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m,
            .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z,
        ]

        // -- Act --
        let expected = "abcdefghijklmnopqrstuvwxyz".map(KeyEvent.character)

        // -- Assert --
        #expect(names == expected)
    }

    @Test("Uppercase letter constants match character events")
    func uppercaseLetters() {
        // -- Arrange --
        let names: [KeyEvent] = [
            .A, .B, .C, .D, .E, .F, .G, .H, .I, .J, .K, .L, .M,
            .N, .O, .P, .Q, .R, .S, .T, .U, .V, .W, .X, .Y, .Z,
        ]

        // -- Act --
        let expected = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(KeyEvent.character)

        // -- Assert --
        #expect(names == expected)
    }

    @Test("Digit constants match character events")
    func digits() {
        // -- Arrange --
        let names: [KeyEvent] = [
            .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine,
        ]

        // -- Act --
        let expected = "0123456789".map(KeyEvent.character)

        // -- Assert --
        #expect(names == expected)
    }

    @Test("Space and punctuation constants match character events")
    func punctuation() {
        // -- Arrange --
        let names: [KeyEvent] = [
            .space, .exclamationMark, .doubleQuote, .numberSign, .dollarSign,
            .percentSign, .ampersand, .apostrophe, .leftParenthesis, .rightParenthesis,
            .asterisk, .plus, .comma, .minus, .period, .slash, .colon, .semicolon,
            .lessThan, .equals, .greaterThan, .questionMark, .atSign, .leftBracket,
            .backslash, .rightBracket, .caret, .underscore, .graveAccent, .leftBrace,
            .pipe, .rightBrace, .tilde,
        ]

        // -- Act --
        let expected = " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~".map(KeyEvent.character)

        // -- Assert --
        #expect(names == expected)
    }
}

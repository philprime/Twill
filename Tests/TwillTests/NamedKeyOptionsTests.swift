import Testing

@testable import Twill

@Suite("Named control and modifier keys")
struct NamedKeyOptionsTests {
    @Test("Named legacy control chords match every decoded ASCII control byte")
    func controls() {
        // -- Arrange --
        var parser = InputParser()
        let named: [KeyEvent] = [
            .controlAt, .controlA, .controlB, .controlC, .controlD, .controlE, .controlF, .controlG,
            .controlH, .controlI, .controlJ, .controlK, .controlL, .controlM, .controlN, .controlO,
            .controlP, .controlQ, .controlR, .controlS, .controlT, .controlU, .controlV, .controlW,
            .controlX, .controlY, .controlZ, .controlLeftBracket, .controlBackslash, .controlRightBracket,
            .controlCaret, .controlUnderscore,
        ]

        // -- Act --
        let decoded = parser.parse(Array(UInt8(0)...UInt8(31)))

        // -- Assert --
        #expect(named == decoded)
        #expect(KeyEvent.controlSpace == .controlAt)
        #expect(KeyEvent.controlQuestionMark == parser.parse([0x7F]).first)
    }

    @Test("Named Super chords preserve the base letter and report the Super modifier")
    func superLetters() {
        // -- Arrange --
        let named: [KeyEvent] = [
            .superA, .superB, .superC, .superD, .superE, .superF, .superG, .superH, .superI,
            .superJ, .superK, .superL, .superM, .superN, .superO, .superP, .superQ, .superR,
            .superS, .superT, .superU, .superV, .superW, .superX, .superY, .superZ,
        ]

        // -- Act --
        let expected = "abcdefghijklmnopqrstuvwxyz".map { KeyEvent.character($0, modifiers: .superKey) }

        // -- Assert --
        #expect(named == expected)
    }

    @Test("Named function keys match the decoder's numbered function-key identities")
    func functionKeys() {
        // -- Arrange --
        let named: [KeyEvent] = [.f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12]

        // -- Act --
        let expected = (1...12).map { KeyEvent.function($0) }

        // -- Assert --
        #expect(named == expected)
    }

    @Test("Modifier composition works for any key and preserves flags already present")
    func modifierComposition() {
        // -- Arrange --
        let shiftedSave = KeyEvent.superS.withModifiers(.shift)
        let navigation = KeyEvent.arrowUp.withModifiers([.alt, .control])

        // -- Act --
        let expectedSave = KeyEvent.character("s", modifiers: [.superKey, .shift])
        let expectedNavigation = KeyEvent(.arrowUp, modifiers: [.alt, .control])

        // -- Assert --
        #expect(shiftedSave == expectedSave)
        #expect(navigation == expectedNavigation)
        #expect(KeyEvent.s.withModifiers([.hyper, .meta]) == .character("s", modifiers: [.hyper, .meta]))
    }

    @Test("CSI-u reports modified Unicode characters, Super-S and named special keys")
    func unicodeReports() {
        // -- Arrange --
        var parser = InputParser()
        let input = "\u{1B}[115;9u\u{1B}[115;10u\u{1B}[30028;3u\u{1B}[9;2u\u{1B}[13;5u"

        // -- Act --
        let events = parser.parse(Array(input.utf8))

        // -- Assert --
        #expect(
            events == [
                .superS, .superS.withModifiers(.shift), .character("界", modifiers: .alt),
                .shiftTab, .init(.enter, modifiers: .control),
            ])
    }

    @Test("Transport chunk boundaries do not change Super-S decoding", arguments: 0...8)
    func splitUnicodeReport(at offset: Int) {
        // -- Arrange --
        var parser = InputParser()
        let bytes = Array("\u{1B}[115;9u".utf8)

        // -- Act --
        let first = parser.parse(Array(bytes.prefix(offset)))
        let second = parser.parse(Array(bytes.dropFirst(offset)))

        // -- Assert --
        #expect(first + second == [.superS])
        #expect(!parser.needsEscapeDeadline)
    }

    @Test("Unsupported CSI-u reports are consumed atomically instead of leaking shortcut characters")
    func invalidReports() {
        // -- Arrange --
        let reports = ["\u{1B}[115;0u", "\u{1B}[115;65u", "\u{1B}[55296;9u", "\u{1B}[57344u", "\u{1B}[115;9:3u"]

        // -- Act --
        let events = reports.map { report in
            var parser = InputParser()
            return parser.parse(Array(report.utf8))
        }

        // -- Assert --
        #expect(events == reports.map { [.init(.unknown(Array($0.utf8)))] })
    }
}

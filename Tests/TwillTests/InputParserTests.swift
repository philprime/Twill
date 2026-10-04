import Testing

@testable import Twill

@Suite("Keyboard byte decoding")
struct InputParserTests {
    @Test("Decodes ordinary keys and controls")
    func basicKeys() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let keys = parser.parse([0x61, 0x20, 0x0D, 0x0A, 0x09, 0x08, 0x7F, 0x00, 0x03])

        // -- Assert --
        #expect(
            keys == [
                .a, .space, .enter, .enter, .tab,
                .backspace, .backspace, .control(0), .control(3),
            ])
        #expect(!parser.needsEscapeDeadline)
    }

    @Test("Named control keys match terminal input")
    func namedControlKeys() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let keys = parser.parse([0x03, 0x04])

        // -- Assert --
        #expect(keys == [.controlC, .controlD])
    }

    @Test("Chunk boundaries do not change UTF-8 or arrow decoding", arguments: 0...17)
    func splitInput(at offset: Int) {
        // -- Arrange --
        var parser = InputParser()
        let bytes: [UInt8] = [
            0xC3, 0xA9, 0xE7, 0x95, 0x8C, 0xF0, 0x9F, 0x98, 0x80,
            0x1B, 0x5B, 0x41, 0x1B, 0x4F, 0x44, 0x62, 0x63,
        ]

        // -- Act --
        let first = parser.parse(Array(bytes.prefix(offset)))
        let second = parser.parse(Array(bytes.dropFirst(offset)))

        // -- Assert --
        #expect(
            first + second == [
                .character("é"), .character("界"), .character("😀"),
                .arrowUp, .arrowLeft, .b, .c,
            ])
    }

    @Test("Decodes arrows in normal and application cursor modes", arguments: [0x5B, 0x4F] as [UInt8])
    func arrows(prefix: UInt8) {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let keys = parser.parse([
            0x1B, prefix, 0x41, 0x1B, prefix, 0x42,
            0x1B, prefix, 0x43, 0x1B, prefix, 0x44,
        ])

        // -- Assert --
        #expect(keys == [.arrowUp, .arrowDown, .arrowRight, .arrowLeft])
    }

    @Test("Decodes Shift-Tab and Page keys across transport chunks")
    func paneKeys() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let first = parser.parse([0x1B, 0x5B, 0x5A, 0x1B, 0x5B, 0x35])
        let second = parser.parse([0x7E, 0x1B, 0x5B, 0x36, 0x7E])

        // -- Assert --
        #expect(first + second == [.shiftTab, .pageUp, .pageDown])
    }

    @Test("Decodes conventional Home and End variants")
    func navigationKeys() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let keys = parser.parse([
            0x1B, 0x5B, 0x48, 0x1B, 0x4F, 0x46,
            0x1B, 0x5B, 0x31, 0x7E, 0x1B, 0x5B, 0x34, 0x7E,
        ])

        // -- Assert --
        #expect(keys == [.home, .end, .home, .end])
    }

    @Test("Conventional navigation and function keys survive every transport split", arguments: 0...21)
    func splitNavigation(at offset: Int) {
        // -- Arrange --
        var parser = InputParser()
        let bytes: [UInt8] = [
            0x1B, 0x5B, 0x32, 0x7E,
            0x1B, 0x5B, 0x33, 0x7E,
            0x1B, 0x5B, 0x32, 0x34, 0x7E,
            0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x48,
            0x61,
        ]

        // -- Act --
        let first = parser.parse(Array(bytes.prefix(offset)))
        let second = parser.parse(Array(bytes.dropFirst(offset)))

        // -- Assert --
        #expect(
            first + second == [
                .insert, .delete, .function(12),
                KeyEvent(.home, modifiers: [.control]), .a,
            ])
    }

    @Test("Preserves modifier combinations on navigation and function keys")
    func modifiedKeys() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let keys = parser.parse([
            0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x48,
            0x1B, 0x5B, 0x33, 0x3B, 0x34, 0x7E,
            0x1B, 0x4F, 0x50,
        ])

        // -- Assert --
        #expect(
            keys == [
                KeyEvent(.home, modifiers: [.control]),
                KeyEvent(.delete, modifiers: [.shift, .alt]),
                .function(1),
            ])
    }

    @Test("Rejects invalid modifier parameters rather than invoking an unmodified shortcut")
    func invalidModifiers() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let keys = parser.parse([0x1B, 0x5B, 0x31, 0x3B, 0x30, 0x48, 0x61])

        // -- Assert --
        #expect(keys == [KeyEvent(.unknown([0x1B, 0x5B, 0x31, 0x3B, 0x30, 0x48])), .a])
    }

    @Test("Oversized escape sequences cannot leak shortcuts or grow the fallback event")
    func oversizedEscape() {
        // -- Arrange --
        var parser = InputParser()
        let prefix: [UInt8] = [0x1B, 0x5B] + Array(repeating: 0x31, count: 100)

        // -- Act --
        let first = parser.parse(prefix)
        let second = parser.parse([0x7E, 0x61])

        // -- Assert --
        #expect(first.isEmpty)
        #expect(second == [.a])
    }

    @Test("Expired oversized sequence cannot swallow later keys")
    func expiredOversizedEscape() {
        // -- Arrange --
        var parser = InputParser()
        let oversized: [UInt8] = [0x1B, 0x5B] + Array(repeating: 0x31, count: 100)
        _ = parser.parse(oversized)

        // -- Act --
        let expired = parser.expireEscape()
        let recovered = parser.parse([0x61])

        // -- Assert --
        #expect(expired.isEmpty)
        #expect(recovered == [.a])
    }

    @Test("A lone Escape waits for its deadline")
    func loneEscape() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let immediate = parser.parse([0x1B])
        let needsDeadline = parser.needsEscapeDeadline
        let expired = parser.expireEscape()
        let expiredAgain = parser.expireEscape()

        // -- Assert --
        #expect(immediate.isEmpty)
        #expect(needsDeadline)
        #expect(expired == [.escape])
        #expect(expiredAgain.isEmpty)
        #expect(!parser.needsEscapeDeadline)
    }

    @Test("Completed sequences invalidate the need for an Escape deadline")
    func completedEscape() {
        // -- Arrange --
        var parser = InputParser()
        _ = parser.parse([0x1B])

        // -- Act --
        let keys = parser.parse([0x5B, 0x42])
        let expired = parser.expireEscape()

        // -- Assert --
        #expect(keys == [.arrowDown])
        #expect(expired.isEmpty)
        #expect(!parser.needsEscapeDeadline)
    }

    @Test("Incomplete and unsupported CSI sequences do not leak keys")
    func unsupportedSequences() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let unsupported = parser.parse([0x1B, 0x5B, 0x39, 0x7E, 0x61])
        let incomplete = parser.parse([0x1B, 0x5B, 0x31])
        let expired = parser.expireEscape()
        let recovered = parser.parse([0x62])

        // -- Assert --
        #expect(unsupported == [KeyEvent(.unknown([0x1B, 0x5B, 0x39, 0x7E])), .a])
        #expect(incomplete.isEmpty)
        #expect(expired.isEmpty)
        #expect(recovered == [.b])
    }

    @Test("Escape followed by an ordinary key preserves both")
    func escapeThenCharacter() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let keys = parser.parse([0x1B, 0x61])

        // -- Assert --
        #expect(keys == [.escape, .a])
    }

    @Test("Invalid UTF-8 cannot hold a following key indefinitely")
    func malformedUTF8() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let keys = parser.parse([0xFF, 0x80, 0xF0, 0x61])

        // -- Assert --
        #expect(keys == [.a])
    }

    @Test("Escape expiry does not discard partial UTF-8")
    func utf8SurvivesExpiry() {
        // -- Arrange --
        var parser = InputParser()
        let partial = parser.parse([0xC3])

        // -- Act --
        let expired = parser.expireEscape()
        let completed = parser.parse([0xA9])

        // -- Assert --
        #expect(partial.isEmpty)
        #expect(expired.isEmpty)
        #expect(completed == [.character("é")])
    }
}

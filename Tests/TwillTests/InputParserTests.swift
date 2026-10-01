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
                .character("a"), .character(" "), .enter, .enter, .tab,
                .backspace, .backspace, .control(0), .control(3),
            ])
        #expect(!parser.needsEscapeDeadline)
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
                .arrowUp, .arrowLeft, .character("b"), .character("c"),
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
        #expect(unsupported == [.character("a")])
        #expect(incomplete.isEmpty)
        #expect(expired.isEmpty)
        #expect(recovered == [.character("b")])
    }

    @Test("Escape followed by an ordinary key preserves both")
    func escapeThenCharacter() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let keys = parser.parse([0x1B, 0x61])

        // -- Assert --
        #expect(keys == [.escape, .character("a")])
    }

    @Test("Invalid UTF-8 cannot hold a following key indefinitely")
    func malformedUTF8() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let keys = parser.parse([0xFF, 0x80, 0xF0, 0x61])

        // -- Assert --
        #expect(keys == [.character("a")])
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

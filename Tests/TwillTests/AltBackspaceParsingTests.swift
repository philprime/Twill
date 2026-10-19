import Testing

@testable import Twill

@Suite("Alt-Backspace transport")
struct AltBackspaceParsingTests {
    @Test(
        "Escape-prefixed Backspace remains one modified key across input chunks", arguments: [UInt8(0x08), UInt8(0x7F)])
    func splitInput(backspace: UInt8) {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let prefix = parser.parse([0x1B])
        let pending = parser.needsEscapeDeadline
        let events = parser.parse([backspace, 0x61])

        // -- Assert --
        #expect(prefix.isEmpty && pending)
        #expect(events == [.backspace.withModifiers(.alt), .a])
        #expect(!parser.needsEscapeDeadline)
    }

    @Test("Other Escape combinations and an expired lone Escape retain their behavior")
    func unrelatedEscapes() {
        // -- Arrange --
        var parser = InputParser()

        // -- Act --
        let enter = parser.parse([0x1B, 0x0D])
        _ = parser.parse([0x1B])
        let expired = parser.expireEscape()

        // -- Assert --
        #expect(enter == [.escape, .enter])
        #expect(expired == [.escape])
    }
}

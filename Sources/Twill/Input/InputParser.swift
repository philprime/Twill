/// Keeps transport chunking separate from keyboard semantics. This value has no
/// platform resources, so callers can decode input on their chosen serialized executor.
struct InputParser {
    private enum Byte {
        static let escape: UInt8 = 0x1B
        static let controlSequenceIntroducer: UInt8 = 0x5B
        static let singleShiftThree: UInt8 = 0x4F
        static let lineFeed: UInt8 = 0x0A
        static let carriageReturn: UInt8 = 0x0D
        static let tab: UInt8 = 0x09
        static let backspace: UInt8 = 0x08
        static let delete: UInt8 = 0x7F
        static let arrowUp: UInt8 = 0x41
        static let arrowDown: UInt8 = 0x42
        static let arrowRight: UInt8 = 0x43
        static let arrowLeft: UInt8 = 0x44

        static let ascii: ClosedRange<UInt8> = 0x00...0x7F
        static let controls: ClosedRange<UInt8> = 0x00...0x1F
        static let utf8TwoByteLead: ClosedRange<UInt8> = 0xC2...0xDF
        static let utf8ThreeByteLead: ClosedRange<UInt8> = 0xE0...0xEF
        static let utf8FourByteLead: ClosedRange<UInt8> = 0xF0...0xF4
        static let utf8Continuation: ClosedRange<UInt8> = 0x80...0xBF
        static let escapeSequenceFinal: ClosedRange<UInt8> = 0x40...0x7E
    }

    // CSI and SS3 both begin with Escape followed by a one-byte introducer.
    private static let sequencePrefixLength = 2

    // A read can split either UTF-8 or an escape sequence at any byte boundary.
    // Retaining the suffix avoids treating OS chunk boundaries as key boundaries.
    private var pending: [UInt8] = []

    var needsEscapeDeadline: Bool { pending.first == Byte.escape }

    mutating func expireEscape() -> [KeyEvent] {
        guard needsEscapeDeadline else { return [] }
        let isLoneEscape = pending.count == 1
        pending.removeAll()
        return isLoneEscape ? [.escape] : []
    }

    mutating func parse(_ bytes: [UInt8]) -> [KeyEvent] {
        pending.append(contentsOf: bytes)
        var events: [KeyEvent] = []
        while let byte = pending.first {
            let consumed = byte == Byte.escape ? consumeEscape(into: &events) : consumeKey(byte, into: &events)
            if !consumed { break }
        }
        return events
    }

    private mutating func consumeEscape(into events: inout [KeyEvent]) -> Bool {
        guard pending.count >= Self.sequencePrefixLength else { return false }
        guard pending[1] == Byte.controlSequenceIntroducer || pending[1] == Byte.singleShiftThree else {
            pending.removeFirst()
            events.append(.escape)
            return true
        }
        guard
            let end = pending.indices.dropFirst(Self.sequencePrefixLength).first(where: {
                Byte.escapeSequenceFinal.contains(pending[$0])
            })
        else { return false }
        if end == Self.sequencePrefixLength, let arrow = Self.arrows[pending[end]] {
            events.append(arrow)
        }
        // Consume unsupported CSI/SS3 sequences as a unit so their parameter bytes
        // cannot accidentally trigger ordinary application shortcuts.
        pending.removeFirst(end + 1)
        return true
    }

    private mutating func consumeKey(_ byte: UInt8, into events: inout [KeyEvent]) -> Bool {
        guard let length = Self.scalarLength(byte) else {
            pending.removeFirst()
            return true
        }
        // An invalid continuation already proves this scalar cannot complete.
        // Do not wait for more bytes while a valid key sits behind it.
        guard pending.prefix(length).dropFirst().allSatisfy(Byte.utf8Continuation.contains) else {
            pending.removeFirst()
            return true
        }
        guard pending.count >= length else { return false }
        if let key = Self.specialKeys[byte] {
            events.append(key)
        } else if Byte.controls.contains(byte) {
            events.append(.control(byte))
        } else if let text = String(validating: pending.prefix(length), as: UTF8.self), let character = text.first {
            events.append(.character(character))
        } else {
            pending.removeFirst()
            return true
        }
        pending.removeFirst(length)
        return true
    }

    private static func scalarLength(_ byte: UInt8) -> Int? {
        switch byte {
        case Byte.ascii: 1
        case Byte.utf8TwoByteLead: 2
        case Byte.utf8ThreeByteLead: 3
        case Byte.utf8FourByteLead: 4
        default: nil
        }
    }

    private static let specialKeys: [UInt8: KeyEvent] = [
        Byte.lineFeed: .enter, Byte.carriageReturn: .enter, Byte.tab: .tab,
        Byte.backspace: .backspace, Byte.delete: .backspace,
    ]
    private static let arrows: [UInt8: KeyEvent] = [
        Byte.arrowUp: .arrowUp, Byte.arrowDown: .arrowDown,
        Byte.arrowRight: .arrowRight, Byte.arrowLeft: .arrowLeft,
    ]
}

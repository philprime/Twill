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
        static let shiftTab: UInt8 = 0x5A

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
    private var discardingEscape = false
    private static let maximumEscapeLength = 64

    var needsEscapeDeadline: Bool { discardingEscape || pending.first == Byte.escape }

    mutating func expireEscape() -> [KeyEvent] {
        guard needsEscapeDeadline else { return [] }
        let isLoneEscape = pending.count == 1 && !discardingEscape
        pending.removeAll()
        discardingEscape = false
        return isLoneEscape ? [.escape] : []
    }

    mutating func parse(_ bytes: [UInt8]) -> [KeyEvent] {
        pending.append(contentsOf: bytes)
        if discardingEscape {
            guard let end = pending.firstIndex(where: { Byte.escapeSequenceFinal.contains($0) }) else {
                pending.removeAll()
                return []
            }
            pending.removeFirst(end + 1)
            discardingEscape = false
        }
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
        else {
            if pending.count > Self.maximumEscapeLength {
                pending.removeAll()
                discardingEscape = true
                return true
            }
            return false
        }
        if end + 1 > Self.maximumEscapeLength {
            pending.removeFirst(end + 1)
            return true
        }
        let sequence = Array(pending[Self.sequencePrefixLength...end])
        if let key = Self.decode(sequence, csi: pending[1] == Byte.controlSequenceIntroducer) {
            events.append(key)
        } else {
            events.append(KeyEvent(.unknown(Array(pending[...end]))))
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

    private static func decode(_ sequence: [UInt8], csi: Bool) -> KeyEvent? {
        guard let final = sequence.last else { return nil }
        let parameters = sequence.dropLast()
        if csi, final == Byte.shiftTab, parameters.isEmpty { return .shiftTab }
        let numbers =
            parameters.isEmpty
            ? []
            : parameters.split(separator: 0x3B, omittingEmptySubsequences: false).compactMap { segment -> Int? in
                guard let text = String(bytes: segment, encoding: .ascii) else { return nil }
                return Int(text)
            }
        guard
            parameters.isEmpty
                || numbers.count == parameters.split(separator: 0x3B, omittingEmptySubsequences: false).count
        else {
            return nil
        }
        guard numbers.count != 2 || (1...64).contains(numbers[1]) else { return nil }
        let modifiers = numbers.count == 2 ? KeyModifiers(rawValue: UInt8(numbers[1] - 1)) : []
        let isUnnumberedKey = numbers.isEmpty || (csi && numbers.count == 2 && numbers[0] == 1)
        if isUnnumberedKey, let key = specialSequenceKeys[final] {
            return KeyEvent(key, modifiers: modifiers)
        }
        guard csi, final == 0x7E, let code = numbers.first, numbers.count == 1 || numbers.count == 2 else {
            return nil
        }
        guard let key = numberedKeys[code] else { return nil }
        return KeyEvent(key, modifiers: modifiers)
    }

    private static let specialSequenceKeys: [UInt8: KeyEvent.Key] = [
        0x41: .arrowUp, 0x42: .arrowDown, 0x43: .arrowRight, 0x44: .arrowLeft,
        0x48: .home, 0x46: .end,
        0x50: .function(1), 0x51: .function(2), 0x52: .function(3), 0x53: .function(4),
    ]

    private static let numberedKeys: [Int: KeyEvent.Key] = [
        1: .home, 2: .insert, 3: .delete, 4: .end, 5: .pageUp, 6: .pageDown,
        7: .home, 8: .end,
        11: .function(1), 12: .function(2), 13: .function(3), 14: .function(4),
        15: .function(5), 17: .function(6), 18: .function(7), 19: .function(8),
        20: .function(9), 21: .function(10), 23: .function(11), 24: .function(12),
    ]

    private static let specialKeys: [UInt8: KeyEvent] = [
        Byte.lineFeed: .enter, Byte.carriageReturn: .enter, Byte.tab: .tab,
        Byte.backspace: .backspace, Byte.delete: .backspace,
    ]
}

extension InputParser {
    private enum UnicodeKeyCode {
        static let tab = 9
        static let lineFeed = 10
        static let enter = 13
        static let escape = 27
        static let backspace = 127
        static let controls = 0...31
        // CSI-u reserves this area for functional keys, not printable text.
        static let functionalKeys = 57344...63743
    }

    /// Decodes the primary CSI-u form without treating unsupported functional
    /// reports as text. Extended reports remain atomic unknown sequences.
    static func decodeUnicodeKey(_ code: Int, modifiers: KeyModifiers) -> KeyEvent? {
        guard let scalar = UnicodeScalar(code), !UnicodeKeyCode.functionalKeys.contains(code) else { return nil }
        let key: KeyEvent.Key
        switch code {
        case UnicodeKeyCode.tab: key = .tab
        case UnicodeKeyCode.lineFeed, UnicodeKeyCode.enter: key = .enter
        case UnicodeKeyCode.escape: key = .escape
        case UnicodeKeyCode.backspace: key = .backspace
        case UnicodeKeyCode.controls: key = .control(UInt8(code))
        default: key = .character(Character(String(scalar)))
        }
        return KeyEvent(key, modifiers: modifiers)
    }
}

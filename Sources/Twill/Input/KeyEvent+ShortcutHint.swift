extension KeyEvent {
    private static let asciiControlLimit: UInt8 = 0x20
    private static let controlCharacterOffset: UInt8 = 0x40
    private static let deleteControlByte: UInt8 = 0x7F

    var shortcutHint: String {
        let flags: [(KeyModifiers, String)] = [
            (.control, "Ctrl"), (.alt, "Alt"), (.shift, "Shift"),
            (.superKey, "Super"), (.hyper, "Hyper"), (.meta, "Meta"),
        ]
        return (flags.compactMap { modifiers.contains($0.0) ? $0.1 : nil } + [shortcutKeyHint])
            .joined(separator: "-")
    }

    private var shortcutKeyHint: String {
        switch key {
        case .character(" "): return "Space"
        case .character(let character): return String(character)
        case .enter: return "Enter"
        case .tab: return "Tab"
        case .backspace: return "Backspace"
        case .escape: return "Esc"
        case .arrowUp: return "Up"
        case .arrowDown: return "Down"
        case .arrowLeft: return "Left"
        case .arrowRight: return "Right"
        case .home: return "Home"
        case .end: return "End"
        case .insert: return "Insert"
        case .delete: return "Delete"
        case .pageUp: return "Page Up"
        case .pageDown: return "Page Down"
        case .function(let number): return "F\(number)"
        case .control(let byte):
            // Legacy terminal control bytes encode Ctrl-@ through Ctrl-_.
            if byte < Self.asciiControlLimit { return "Ctrl-\(UnicodeScalar(byte + Self.controlCharacterOffset))" }
            if byte == Self.deleteControlByte { return "Ctrl-?" }
            return "Control-0x\(Self.shortcutHex(byte))"
        case .unknown(let bytes):
            return "Unknown(\(bytes.map(Self.shortcutHex).joined(separator: " ")))"
        }
    }

    private static func shortcutHex(_ byte: UInt8) -> String {
        (byte < 0x10 ? "0" : "") + String(byte, radix: 16, uppercase: true)
    }
}

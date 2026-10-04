/// Basic terminal keys. Modifier protocols and bracketed paste are not decoded yet.
/// Text is delivered one Unicode scalar at a time, not as composed grapheme clusters.
public enum KeyEvent: Sendable, Equatable {
    case character(Character)
    case enter
    case tab
    case shiftTab
    case pageUp
    case pageDown
    case backspace
    case escape
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case control(UInt8)

    /// Ctrl-C, usually used to request orderly shutdown.
    public static let controlC = Self.control(0x03)

    /// Ctrl-D, conventionally associated with end-of-input.
    public static let controlD = Self.control(0x04)
}

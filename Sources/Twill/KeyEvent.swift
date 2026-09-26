/// Basic terminal keys. Modifier protocols and bracketed paste are not decoded yet.
/// Text is delivered one Unicode scalar at a time, not as composed grapheme clusters.
public enum KeyEvent: Sendable, Equatable {
    case character(Character)
    case enter
    case tab
    case backspace
    case escape
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case control(UInt8)
}

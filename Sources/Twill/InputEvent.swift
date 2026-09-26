/// Transport events, before keyboard interpretation. Failures retain their operation and errno.
public enum InputEvent: Sendable {
    case bytes([UInt8])
    case endOfFile
    case failure(TerminalError)
}

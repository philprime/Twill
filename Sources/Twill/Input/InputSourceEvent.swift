/// A lossless event produced by a terminal input descriptor.
public enum InputSourceEvent: Sendable {
    case bytes([UInt8])
    case end
    case failure(any Error)
}

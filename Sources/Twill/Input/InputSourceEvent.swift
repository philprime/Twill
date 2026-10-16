/// A lossless event produced by a terminal input descriptor.
public enum InputSourceEvent: Sendable {
    /// An uninterpreted chunk of bytes read from the input descriptor.
    case bytes([UInt8])
    /// The input descriptor reached end-of-input.
    case end
    /// Input configuration or reading failed with the associated error.
    case failure(any Error)
}

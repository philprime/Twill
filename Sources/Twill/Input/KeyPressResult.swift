/// Whether a view consumed a key or allows it to reach an enclosing handler.
public enum KeyPressResult: Sendable, Equatable {
    /// Consumes the key and prevents enclosing handlers from receiving it.
    case handled
    /// Allows the key to continue to enclosing handlers.
    case ignored
}

/// Whether a view consumed a key or allows it to reach an enclosing handler.
public enum KeyPressResult: Sendable, Equatable {
    case handled
    case ignored
}

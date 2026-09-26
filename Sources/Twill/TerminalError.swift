/// Identifies the failed operation as well as the POSIX errno captured at its call site.
/// The same errno can arise during setup or reading, so preserve that context for callers.
public enum TerminalError: Error, Sendable, Equatable {
    case readAttributes(errno: Int32)
    case writeAttributes(errno: Int32)
    case configureInput(errno: Int32)
    case readInput(errno: Int32)
}

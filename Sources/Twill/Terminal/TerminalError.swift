/// Identifies the failed operation as well as the POSIX errno captured at its call site.
/// The same errno can arise during setup or reading, so preserve that context for callers.
public enum TerminalError: Error, Sendable, Equatable {
    /// Reading the terminal viewport dimensions failed with the captured POSIX error.
    case readSize(errno: Int32)
    /// Reading the inherited terminal attributes failed with the captured POSIX error.
    case readAttributes(errno: Int32)
    /// Applying terminal input attributes failed with the captured POSIX error.
    case writeAttributes(errno: Int32)
    /// Reading or enabling nonblocking input flags failed with the captured POSIX error.
    case configureInput(errno: Int32)
    /// Reading bytes from the input descriptor failed with the captured POSIX error.
    case readInput(errno: Int32)
}

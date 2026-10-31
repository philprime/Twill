/// Image output supported by a terminal capability snapshot.
public enum TerminalImageProtocol: Equatable, Sendable {
    /// No supported graphics protocol is available.
    case none
    /// Kitty-compatible PNG uploads and owned image placements.
    case kitty
}

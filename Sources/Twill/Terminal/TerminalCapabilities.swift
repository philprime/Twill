import Foundation

/// An immutable, caller-overridable terminal capability snapshot.
public struct TerminalCapabilities: Equatable, Sendable {
    /// The supported terminal image protocol.
    public let imageProtocol: TerminalImageProtocol
    /// Physical cell height divided by width. The default assumes cells are twice as tall as wide.
    public let cellHeightToWidth: Double

    /// Creates explicit capabilities with a finite positive cell aspect assumption.
    public init(imageProtocol: TerminalImageProtocol = .none, cellHeightToWidth: Double = 2) {
        precondition(cellHeightToWidth.isFinite && cellHeightToWidth > 0, "Cell aspect must be finite and positive")
        self.imageProtocol = imageProtocol
        self.cellHeightToWidth = cellHeightToWidth
    }

    /// Reads known environment hints, not active terminal protocol responses.
    /// Supply explicit capabilities when hints are unavailable or inaccurate.
    public static func detect(environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        let supported =
            environment["TERM_PROGRAM"] == "ghostty" || environment["TERM"] == "xterm-kitty"
            || environment["TERM"] == "xterm-ghostty"
        return Self(imageProtocol: supported ? .kitty : .none)
    }
}

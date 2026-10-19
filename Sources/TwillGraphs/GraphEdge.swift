import Twill

/// A connection between two node identities. Directed edges display an arrow at the target.
public struct GraphEdge<ID: Hashable & Sendable>: Sendable, Equatable {
    /// The originating node.
    public let source: ID
    /// The destination node.
    public let target: ID
    /// Whether traversal and arrow rendering respect the connection's orientation.
    public let directed: Bool
    /// The connection's stroke color.
    public var color: PixelColor
    /// The positive stroke width in bitmap pixels at the default zoom.
    public let width: Double

    /// Creates a connection. Undirected connections are the default.
    public init(
        from source: ID, to target: ID, directed: Bool = false,
        color: PixelColor = PixelColor(red: 110, green: 120, blue: 140), width: Double = 1
    ) {
        precondition(width.isFinite && width > 0)
        self.source = source
        self.target = target
        self.directed = directed
        self.color = color
        self.width = width
    }
}

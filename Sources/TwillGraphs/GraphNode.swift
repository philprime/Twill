import Twill

/// An identified node and its bitmap appearance. Labels appear in the graph's selection caption.
public struct GraphNode<ID: Hashable & Sendable>: Identifiable, Sendable, Equatable {
    /// Stable identity retained when the node's appearance changes.
    public let id: ID
    /// A human-readable name.
    public var label: String
    /// The node's fill color.
    public var color: PixelColor
    /// The positive radius in bitmap pixels at the default zoom.
    public let radius: Double

    /// Creates a node, using its identity as the default label.
    public init(
        id: ID, label: String? = nil,
        color: PixelColor = PixelColor(red: 166, green: 139, blue: 250), radius: Double = 5
    ) {
        precondition(radius.isFinite && radius > 0)
        self.id = id
        self.label = label ?? String(describing: id)
        self.color = color
        self.radius = radius
    }
}

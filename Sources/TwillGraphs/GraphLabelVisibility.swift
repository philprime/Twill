/// Controls whether node names are drawn in the graph's pixel surface.
public enum GraphLabelVisibility: Sendable {
    /// Show names only in the terminal-text selection caption.
    case hidden
    /// Show collision-aware labels, prioritizing selection and connected nodes.
    /// Text stays the same size while zooming. At overview scales, only the
    /// selected node and highly connected nodes are eligible.
    case automatic
}

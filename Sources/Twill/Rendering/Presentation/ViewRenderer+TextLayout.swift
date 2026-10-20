@MainActor
extension ViewRenderer {
    var textLayout: TextLayoutConfiguration {
        var lineBreakMode: Text.LineBreakMode?
        var lineLimit: Int?
        var hasLineLimit = false
        var truncationMode: Text.TruncationMode?
        var ancestor: ViewRenderer? = self
        while let node = ancestor {
            if case .textLayout(_, let change) = node.description {
                switch change {
                case .lineBreakMode(let mode) where lineBreakMode == nil: lineBreakMode = mode
                case .lineLimit(let limit) where !hasLineLimit:
                    lineLimit = limit
                    hasLineLimit = true
                case .truncationMode(let mode) where truncationMode == nil: truncationMode = mode
                default: break
                }
            }
            ancestor = node.parent
        }
        return TextLayoutConfiguration(
            lineBreakMode: lineBreakMode ?? .wordWrapping, lineLimit: lineLimit, truncationMode: truncationMode)
    }
}

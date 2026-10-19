@MainActor
extension ViewRenderer {
    var textLayout: TextLayoutConfiguration {
        var alignment: HorizontalAlignment?
        var lineBreakMode: Text.LineBreakMode?
        var lineLimit: Int?
        var hasLineLimit = false
        var truncationMode: Text.TruncationMode?
        var ancestor: ViewRenderer? = self
        while let node = ancestor {
            if case .textLayout(_, let change) = node.description {
                switch change {
                case .alignment(let value) where alignment == nil: alignment = value
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
            alignment: alignment ?? .leading,
            lineBreakMode: lineBreakMode ?? .wordWrapping, lineLimit: lineLimit, truncationMode: truncationMode)
    }
}

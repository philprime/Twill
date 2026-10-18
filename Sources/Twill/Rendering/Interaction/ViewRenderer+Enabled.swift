/// Disabled state is inherited through mounted ancestors, independently of layout.
extension ViewRenderer {
    var isEnabled: Bool {
        var ancestor: ViewRenderer? = self
        while let node = ancestor {
            if case .disabled(_, true) = node.description { return false }
            ancestor = node.parent
        }
        return true
    }
}

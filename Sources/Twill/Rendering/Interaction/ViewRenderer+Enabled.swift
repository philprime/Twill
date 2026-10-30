/// Disabled state is inherited within each interaction scope, independently of layout.
extension ViewRenderer {
    var isEnabled: Bool {
        var ancestor: ViewRenderer? = self
        while let node = ancestor {
            if case .disabled(_, true) = node.description { return false }
            // Presented content owns interaction independently of the retained base.
            if case .sheet(_, let isPresented, _) = node.description, isPresented.wrappedValue { return true }
            ancestor = node.parent
        }
        return true
    }
}

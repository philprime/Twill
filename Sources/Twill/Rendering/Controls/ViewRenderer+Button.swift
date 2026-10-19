@MainActor
extension ViewRenderer {
    /// Direct dialog activation and shortcuts share action-before-dismissal ordering.
    func activateButton() {
        guard isEnabled, case .button(let button) = description else { return }
        button.action()
        var ancestor = parent
        while let node = ancestor {
            if case .dialog(_, let isPresented, _) = node.description {
                isPresented.wrappedValue = false
                return
            }
            // A sheet nested in a dialog owns its own dismissal.
            if case .sheet = node.description { return }
            ancestor = node.parent
        }
    }
}

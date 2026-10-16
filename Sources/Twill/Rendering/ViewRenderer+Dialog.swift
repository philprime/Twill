@MainActor
extension ViewRenderer {
    var buttonRole: ButtonRole? {
        guard case .button(_, let role, _) = description else { return nil }
        return role
    }

    var enclosingButton: ViewRenderer? {
        var node: ViewRenderer? = self
        while let current = node {
            if case .button = current.description { return current }
            if case .dialog = current.description { return nil }
            node = current.parent
        }
        return nil
    }

    func dialogButtons() -> [ViewRenderer] {
        if case .button = description { return [self] }
        if case .sheet = description { return [] }
        return children.flatMap { $0.dialogButtons() }
    }

    func dialogScope() -> ViewRenderer? {
        if case .dialog = description { return self }
        if case .sheet = description { return nil }
        return children.lazy.compactMap { $0.dialogScope() }.first
    }

    func handleDialogKey(_ key: KeyEvent) -> Bool {
        guard let dialog = sheetBranch?.dialogScope(),
            case .dialog(_, let isPresented, _) = dialog.description
        else { return false }
        let button: ViewRenderer?
        if key == .escape {
            button = dialog.dialogButtons().first { $0.buttonRole == .cancel }
        } else if key == .enter {
            button = focusTarget()?.enclosingButton
            guard let button, dialog.dialogButtons().contains(where: { $0 === button }) else { return false }
        } else {
            return false
        }
        if case .button(_, _, let action) = button?.description { action() }
        isPresented.wrappedValue = false
        return true
    }
}

import Foundation

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
        return retainedChildren.flatMap { $0.dialogButtons() }
    }

    func dialogScope() -> ViewRenderer? {
        if case .dialog = description { return self }
        if case .sheet = description { return nil }
        for child in retainedChildren {
            if let dialog = child.dialogScope() { return dialog }
        }
        return nil
    }

    func handleDialogKey(_ key: KeyEvent) -> Bool {
        guard let dialog = sheetBranch?.dialogScope(),
            case .dialog(_, let isPresented, _) = dialog.description
        else { return false }
        let button: ViewRenderer?
        if key == .escape {
            button = dialog.dialogButtons().first { $0.isEnabled && $0.buttonRole == .cancel }
        } else if key == .enter {
            button = focusTarget()?.enclosingButton
            guard let button, button.isEnabled, dialog.dialogButtons().contains(where: { $0 === button }) else {
                return false
            }
        } else {
            return false
        }
        if let button { button.activateButton() } else { isPresented.wrappedValue = false }
        return true
    }

    func updateDialog(_ actions: any View, kind: DialogKind, at date: Date) {
        // Mount the supplied actions first so roles in conditional and custom views
        // are resolved without evaluating their bodies a second time.
        let previousFallback = retainedChildren.dropFirst().first
        childStorage.nodes = Array(retainedChildren.prefix(1))
        reconcile([actions], at: date)
        if let previousFallback { childStorage.nodes.append(previousFallback) }
        updateDialogFallback(kind: kind, at: date)
    }

    func updateDialogFallback(kind: DialogKind, at date: Date) {
        let buttons = retainedChildren.first?.dialogButtons() ?? []
        let needsFallback =
            kind == .confirmation ? !buttons.contains { $0.isEnabled && $0.buttonRole == .cancel } : buttons.isEmpty
        guard needsFallback else {
            if retainedChildren.count > 1 { childStorage.nodes.removeLast().unmount() }
            return
        }
        // Keep a mounted fallback stable across both parent and descendant updates.
        guard retainedChildren.count == 1 else { return }
        let fallback = Button(kind == .confirmation ? "Cancel" : "OK", role: kind == .confirmation ? .cancel : nil) {}
        let node = makeChild(fallback)
        node.parent = self
        node.update(fallback, at: date)
        childStorage.nodes.append(node)
    }
}

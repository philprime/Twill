import Foundation

@MainActor
extension ViewRenderer {
    func updateSheet(_ sheet: SheetDescription, at date: Date) {
        if sheet.isPresented.wrappedValue {
            let lifetime = sheetState.begin(identity: sheet.identity, onDismiss: sheet.onDismiss)
            let scope = lifetime.actionScope
            let dismiss = DismissAction { [weak self, weak scope] in
                guard let scope else { return }
                self?.dismissSheet(scope: scope)
            }
            reconcile([sheet.base, sheet.content(dismiss)], at: date)
        } else {
            // Revoke actions before child removal or a reentrant lifecycle callback.
            sheetState.current?.onDismiss = sheet.onDismiss
            let onDismiss = sheetState.end()
            reconcile([sheet.base], at: date)
            if onDismiss != nil { restoreFocusAfterSheetDismissal() }
            onDismiss?()
        }
    }

    private func dismissSheet(scope: MountedSheetActionScope) {
        guard sheetState.current?.actionScope === scope, case .sheet(let sheet) = description,
            sheet.isPresented.wrappedValue
        else { return }
        sheet.isPresented.wrappedValue = false
        // Custom bindings need not be backed by State. The request still wakes this node.
        markDirty()
    }

    func dismissSheetOnEscape(_ key: KeyEvent) -> Bool {
        guard key == .escape, case .sheet(let sheet) = description, sheet.dismissalPolicy == .escape,
            let scope = sheetState.current?.actionScope
        else { return false }
        dismissSheet(scope: scope)
        return true
    }
}

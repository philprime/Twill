import Foundation

@MainActor
extension ViewRenderer {
    /// Open the mounted label's concrete type only within this update. The callback
    /// is weak so retained presentation content cannot own its mounted action node.
    func updateButtonContent<Label: View>(_ label: Label, at date: Date) {
        reconcile([mountedButtonContent(label)], at: date)
    }

    @ViewBuilder
    private func mountedButtonContent<Label: View>(_ label: Label) -> some View {
        if menuAncestor != nil {
            HStack(alignment: .top, spacing: 0) {
                actionLabel(label)
                MenuButtonHints()
            }
        } else {
            actionLabel(label)
        }
    }

    private func actionLabel<Label: View>(_ label: Label) -> some View {
        label.focusable().onKeyPress { [weak self] key in
            guard key == .enter else { return .ignored }
            self?.activateButton()
            return .handled
        }
    }

    /// Focused activation and shortcuts share action-before-dismissal ordering.
    func activateButton() {
        guard isEnabled, case .button(let button) = description else { return }
        button.action()
        var ancestor = parent
        var dismissedMenu = false
        var crossesMenuSheet = false
        while let node = ancestor {
            switch node.description {
            case .menuOpener:
                return
            case .menu(_, let isPresented):
                isPresented.wrappedValue = false
                dismissedMenu = true
                crossesMenuSheet = true
            case .dialog(_, let isPresented, _):
                if !dismissedMenu { isPresented.wrappedValue = false }
                return
            case .sheet:
                // Each menu owns one sheet. Other modal boundaries remain independent.
                guard crossesMenuSheet else { return }
                crossesMenuSheet = false
            default:
                break
            }
            ancestor = node.parent
        }
    }
}

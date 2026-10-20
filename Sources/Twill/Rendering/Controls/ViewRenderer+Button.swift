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
        if hasMenuScope {
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

    private var hasMenuScope: Bool {
        var ancestor = parent
        while let node = ancestor {
            if case .menu = node.description { return true }
            if case .sheet = node.description { return false }
            ancestor = node.parent
        }
        return false
    }

    var menuButtonSuffix: String? {
        guard case .button(let button) = description else { return nil }
        var shortcuts = button.shortcuts
        var ancestor = parent
        while let node = ancestor {
            if case .keyboardShortcut(_, let alternatives) = node.description {
                if node.shortcutButton(requiringEnabled: false) === self { shortcuts += alternatives }
            }
            if case .menu = node.description {
                let hints = shortcuts.map(\.hint).joined(separator: "/")
                return (hints.isEmpty ? "" : "  [\(hints)]") + (isEnabled ? "" : " (disabled)")
            }
            if case .sheet = node.description { return nil }
            ancestor = node.parent
        }
        return nil
    }

    /// Focused activation and shortcuts share action-before-dismissal ordering.
    func activateButton() {
        guard isEnabled, case .button(let button) = description else { return }
        button.action()
        var ancestor = parent
        while let node = ancestor {
            switch node.description {
            case .dialog(_, let isPresented, _), .menu(_, let isPresented):
                isPresented.wrappedValue = false
                return
            case .sheet:
                // A nested sheet owns its own dismissal, not its ancestor's action scope.
                return
            default:
                ancestor = node.parent
            }
        }
    }
}

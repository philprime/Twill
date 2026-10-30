extension ViewRenderer {
    func controlEnvironment(inheriting inherited: ControlEnvironment) -> ControlEnvironment {
        var environment = inherited
        switch description {
        case .controlStyle(_, let style): environment.style = style
        case .button:
            environment.owner = self
            environment.kind = .button
            environment.selected = environment.rowSelected
        case .controlPresentation(_, let kind, let selected):
            environment.owner = self
            environment.kind = kind
            environment.selected =
                kind == .toggle || kind == .picker || kind == .disclosure
                ? selected : environment.rowSelected
        case .controlSelection(_, let selected):
            environment.selected = selected
        case .listRow(_, let selected):
            environment.rowSelected = selected
            environment.selected = selected
        default: break
        }
        return environment
    }

    func controlAppearance(focused: ViewRenderer?) -> ControlAppearance {
        guard let kind = layoutState.controlKind, let owner = layoutState.controlOwner,
            let style = layoutState.controlStyle
        else { return ControlAppearance() }
        let enabled = isEnabled
        let state = ControlState(
            kind: kind, isFocused: enabled && focused?.layoutState.controlOwner === owner,
            isEnabled: enabled, isSelected: layoutState.controlSelected)
        return style.resolve(state, in: layoutState.styleContext)
    }
}

enum DialogKind {
    case alert
    case confirmation
}

/// Keeps action policy inside the mounted modal scope, separate from its layout.
struct DialogActions<Actions: View>: View, PrimitiveView {
    typealias Body = Never
    let actions: Actions
    let isPresented: Binding<Bool>
    let kind: DialogKind

    func makeDescription() -> ViewDescription {
        .dialog(actions, isPresented: isPresented, kind: kind)
    }
}

/// Metadata stays separate from key handlers, preserving existing control behavior.
struct ControlPresentationView<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let kind: ControlKind
    let selected: Bool

    func makeDescription() -> ViewDescription { .controlPresentation(content, kind: kind, selected: selected) }
}

struct ControlSelectionView<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let selected: Bool

    func makeDescription() -> ViewDescription { .controlSelection(content, selected) }
}

extension View {
    func controlPresentation(_ kind: ControlKind, selected: Bool = false) -> some View {
        ControlPresentationView(content: self, kind: kind, selected: selected)
    }

    func controlSelection(_ selected: Bool) -> some View { ControlSelectionView(content: self, selected: selected) }
}

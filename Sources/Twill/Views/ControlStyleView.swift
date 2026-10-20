struct ControlStyleView<Content: View, AppliedStyle: ControlStyle>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let style: AppliedStyle

    func makeDescription() -> ViewDescription { .controlStyle(content, style) }
}

extension View {
    /// Supplies state-aware appearance to descendant controls. A nearer declaration
    /// replaces it, while ordinary text outside controls remains unchanged.
    public func controlStyle<S: ControlStyle>(_ style: S) -> some View {
        ControlStyleView(content: self, style: style)
    }
}

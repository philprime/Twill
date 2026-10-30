/// The concrete content type is retained until the mounted runtime boundary.
struct TintView<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let tint: Color?

    func makeDescription() -> ViewDescription { .tint(content, tint) }
}

extension View {
    /// Sets control emphasis without recoloring ordinary text. Nil clears an inherited
    /// tint override; explicit foreground styles remain independent of control tint.
    public func tint(_ color: Color?) -> some View { TintView(content: self, tint: color) }
}

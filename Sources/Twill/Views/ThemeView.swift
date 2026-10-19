/// The concrete content type is retained until the mounted runtime boundary.
struct ThemeView<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let theme: Theme

    func makeDescription() -> ViewDescription { .theme(content, theme) }
}

extension View {
    /// Supplies a semantic palette to this subtree. More local boundaries replace
    /// it without remounting state or changing schedules.
    public func theme(_ theme: Theme) -> some View { ThemeView(content: self, theme: theme) }
}

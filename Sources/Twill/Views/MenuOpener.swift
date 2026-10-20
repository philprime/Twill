/// Opening a child presentation is distinct from performing a leaf menu action.
struct MenuOpener<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    func makeDescription() -> ViewDescription { .menuOpener(content) }
}

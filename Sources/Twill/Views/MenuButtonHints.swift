/// Menu metadata is resolved after mounting, when shortcut wrappers own their children.
struct MenuButtonHints: View, PrimitiveView {
    typealias Body = Never
    func makeDescription() -> ViewDescription { .menuButtonHints }
}

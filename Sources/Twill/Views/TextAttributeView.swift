/// Concrete composition stays typed until the mounted description boundary.
struct TextAttributeView<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let attributes: TextAttributes
    let mask: TextAttributes

    func makeDescription() -> ViewDescription { .attributes(content, attributes, mask: mask) }
}

extension View {
    /// Sets the inherited bold flag. False overrides an enabled ancestor.
    public func bold(_ active: Bool = true) -> some View {
        TextAttributeView(content: self, attributes: active ? .bold : [], mask: .bold)
    }

    /// Sets the inherited reduced-intensity flag.
    public func dim(_ active: Bool = true) -> some View {
        TextAttributeView(content: self, attributes: active ? .dim : [], mask: .dim)
    }

    /// Sets the inherited italic flag, when supported by the terminal.
    public func italic(_ active: Bool = true) -> some View {
        TextAttributeView(content: self, attributes: active ? .italic : [], mask: .italic)
    }

    /// Sets the inherited underline flag.
    public func underline(_ active: Bool = true) -> some View {
        TextAttributeView(content: self, attributes: active ? .underline : [], mask: .underline)
    }

    /// Replaces inherited text flags. An empty set clears all supported flags.
    public func textAttributes(_ attributes: TextAttributes) -> some View {
        TextAttributeView(content: self, attributes: attributes, mask: .supported)
    }
}

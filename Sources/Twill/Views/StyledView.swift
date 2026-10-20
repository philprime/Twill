/// Applies a terminal style to a view and its descendants.
public struct StyledView<Content: View, AppliedStyle: Style>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never

    enum Role {
        case foreground
        case background
    }

    let content: Content
    let style: AppliedStyle
    let role: Role
}

extension View {
    /// Sets a semantic foreground role, supporting inferred values such as `.accent`.
    public func foregroundStyle(_ style: SemanticColor) -> StyledView<Self, SemanticColor> {
        StyledView(content: self, style: style, role: .foreground)
    }

    /// Sets a semantic background role, supporting inferred values such as `.background`.
    public func backgroundStyle(_ style: SemanticColor) -> StyledView<Self, SemanticColor> {
        StyledView(content: self, style: style, role: .background)
    }

    /// Sets the inherited foreground color for this content using the supplied style.
    public func foregroundStyle<S: Style>(_ style: S) -> StyledView<Self, S> {
        StyledView(content: self, style: style, role: .foreground)
    }

    /// Sets the inherited background color for this content using the supplied style.
    public func backgroundStyle<S: Style>(_ style: S) -> StyledView<Self, S> {
        StyledView(content: self, style: style, role: .background)
    }
}

extension StyledView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        switch role {
        case .foreground: .styled(content, foreground: style, background: nil)
        case .background: .styled(content, foreground: nil, background: style)
        }
    }
}

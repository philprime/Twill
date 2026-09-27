/// Applies a terminal style to a view and its descendants.
public struct StyledView<Content: View, AppliedStyle: Style>: View {
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
    public func foregroundStyle<S: Style>(_ style: S) -> StyledView<Self, S> {
        StyledView(content: self, style: style, role: .foreground)
    }

    public func backgroundStyle<S: Style>(_ style: S) -> StyledView<Self, S> {
        StyledView(content: self, style: style, role: .background)
    }
}

extension StyledView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        switch role {
        case .foreground: .styled(content, foreground: style.color, background: nil)
        case .background: .styled(content, foreground: nil, background: style.color)
        }
    }
}

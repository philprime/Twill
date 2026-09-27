/// Builds fixed-position children and conditional branches. Dynamic keyed collections
/// are deliberately outside this initial structural-identity model.
@resultBuilder
@MainActor
public enum ViewBuilder {
    public static func buildBlock<each Content: View>(
        _ children: repeat each Content
    ) -> ViewList<repeat each Content> {
        ViewList(children: (repeat each children))
    }

    public static func buildOptional<Content: View>(_ content: Content?) -> ConditionalContent<Content, EmptyView> {
        if let content { return ConditionalContent(storage: .first(content)) }
        return ConditionalContent(storage: .second(EmptyView()))
    }

    public static func buildEither<First: View, Second: View>(
        first content: First
    ) -> ConditionalContent<First, Second> {
        ConditionalContent(storage: .first(content))
    }

    public static func buildEither<First: View, Second: View>(
        second content: Second
    ) -> ConditionalContent<First, Second> {
        ConditionalContent(storage: .second(content))
    }
}

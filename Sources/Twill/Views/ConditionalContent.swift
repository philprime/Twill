/// A builder branch occupies a stable structural position even when it has no content.
public struct ConditionalContent<First: View, Second: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never

    enum Storage {
        case first(First)
        case second(Second)
    }

    let storage: Storage
}

extension ConditionalContent: PrimitiveView {
    func makeDescription() -> ViewDescription {
        switch storage {
        case .first(let content): .conditional(first: true, content: content)
        case .second(let content): .conditional(first: false, content: content)
        }
    }
}

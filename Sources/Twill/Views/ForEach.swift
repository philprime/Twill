/// Keeps dynamic children typed until their stable IDs enter the mounted tree.
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    public typealias Body = Never
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let content: @MainActor (Data.Element) -> Content

    /// Creates views for a collection, matching each child by the selected identity.
    /// Choose a stable, unique key so moving an element retains its mounted state.
    public init(
        _ data: Data, id: KeyPath<Data.Element, ID>,
        @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content
    ) {
        self.data = data
        self.id = id
        self.content = content
    }
}

extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    /// Creates views identified by each element's `id` property.
    public init(_ data: Data, @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content) {
        self.init(data, id: \.id, content: content)
    }
}

extension ForEach: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .keyed(children: data.map { (id: AnyHashable($0[keyPath: id]), view: content($0)) })
    }
}

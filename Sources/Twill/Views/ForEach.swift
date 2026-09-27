/// Keeps dynamic children typed until their stable IDs enter the mounted tree.
public struct ForEach<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    public typealias Body = Never
    private let data: Data
    private let content: @MainActor (Data.Element) -> Content

    public init(_ data: Data, @ViewBuilder content: @escaping @MainActor (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
}

extension ForEach: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .keyed(children: data.map { (id: AnyHashable($0.id), view: content($0)) })
    }
}

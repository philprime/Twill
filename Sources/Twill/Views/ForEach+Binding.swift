extension ForEach where Data: MutableCollection {
    /// Creates editable rows identified by stable, unique keys.
    /// Row bindings resolve the current element by ID on each access, so they follow
    /// reordering and insertion. A row binding is invalid after its element is removed
    /// or its ID changes. Keep IDs unchanged when editing through these bindings.
    public init(
        _ data: Binding<Data>, id: KeyPath<Data.Element, ID>,
        @ViewBuilder content: @escaping @MainActor (Binding<Data.Element>) -> Content
    ) {
        self.init(data.wrappedValue, id: id) { element in
            let elementID = element[keyPath: id]
            let binding = Binding<Data.Element>(
                get: {
                    guard let element = data.wrappedValue.first(where: { $0[keyPath: id] == elementID }) else {
                        preconditionFailure("A bound ForEach element must remain in the collection with the same ID")
                    }
                    return element
                },
                set: { newValue in
                    var value = data.wrappedValue
                    guard let index = value.firstIndex(where: { $0[keyPath: id] == elementID }) else {
                        preconditionFailure("A bound ForEach element must remain in the collection with the same ID")
                    }
                    value[index] = newValue
                    data.wrappedValue = value
                })
            return content(binding)
        }
    }
}

extension ForEach where Data: MutableCollection, Data.Element: Identifiable, ID == Data.Element.ID {
    /// Creates editable rows using each element's stable, unique `id`.
    /// Bindings follow the element across reordering and are invalid after its removal or ID change.
    public init(
        _ data: Binding<Data>,
        @ViewBuilder content: @escaping @MainActor (Binding<Data.Element>) -> Content
    ) {
        self.init(data, id: \.id, content: content)
    }
}

extension Binding where Value: MutableCollection {
    /// Projects an element at an index that must remain valid in the current collection.
    /// This binding follows the position, not an element's identity, across structural changes.
    public subscript(index: Value.Index) -> Binding<Value.Element> {
        Binding<Value.Element>(
            get: { wrappedValue[index] },
            set: { newValue in
                var value = wrappedValue
                value[index] = newValue
                wrappedValue = value
            })
    }
}

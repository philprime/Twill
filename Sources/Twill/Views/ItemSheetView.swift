/// Presents an identifiable payload in a separate keyboard scope.
/// Matching IDs update content without replacing mounted state; changed IDs replace it.
public struct ItemSheetView<Content: View, Item: Identifiable, Presented: View>: View {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    private let content: Content
    private let item: Binding<Item?>
    private let presentedContent: @MainActor (Item) -> Presented

    init(content: Content, item: Binding<Item?>, presentedContent: @escaping @MainActor (Item) -> Presented) {
        self.content = content
        self.item = item
        self.presentedContent = presentedContent
    }
}

extension View {
    /// Presents a non-nil payload. Nil dismisses and restores underlying focus.
    /// A matching payload ID retains state while delivering updated values to content.
    public func sheet<Item: Identifiable, Presented: View>(
        item: Binding<Item?>, @ViewBuilder content: @escaping @MainActor (Item) -> Presented
    ) -> ItemSheetView<Self, Item, Presented> {
        ItemSheetView(content: self, item: item, presentedContent: content)
    }
}

extension ItemSheetView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        let isPresented = Binding(
            get: { item.wrappedValue != nil },
            set: { presented in
                if !presented { item.wrappedValue = nil }
            })
        return .sheet(
            base: content, isPresented: isPresented,
            content: {
                ItemSheetContent(item: item.wrappedValue, presentedContent: presentedContent)
            })
    }
}

/// Keying inside the existing sheet keeps the base and modal focus scope stable.
private struct ItemSheetContent<Item: Identifiable, Presented: View>: View {
    let item: Item?
    let presentedContent: @MainActor (Item) -> Presented
    @ViewBuilder var body: some View {
        if let item { presentedContent(item).id(item.id) }
    }
}

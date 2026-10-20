/// Presents an identifiable payload in a separate keyboard scope.
/// Matching IDs update content without replacing mounted state; changed IDs replace it.
public struct ItemSheetView<Content: View, Item: Identifiable, Presented: View>: View {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    private let content: Content
    private let item: Binding<Item?>
    private let dismissalPolicy: SheetDismissalPolicy
    private let onDismiss: @MainActor () -> Void
    private let presentedContent: @MainActor (Item, DismissAction) -> Presented

    init(
        content: Content, item: Binding<Item?>, dismissalPolicy: SheetDismissalPolicy,
        onDismiss: @escaping @MainActor () -> Void,
        presentedContent: @escaping @MainActor (Item, DismissAction) -> Presented
    ) {
        self.content = content
        self.item = item
        self.dismissalPolicy = dismissalPolicy
        self.onDismiss = onDismiss
        self.presentedContent = presentedContent
    }
}

extension View {
    /// Presents a non-nil payload. Matching IDs retain state while receiving fresh values.
    public func sheet<Item: Identifiable, Presented: View>(
        item: Binding<Item?>, dismissalPolicy: SheetDismissalPolicy = .escape,
        onDismiss: @escaping @MainActor () -> Void = {},
        @ViewBuilder content: @escaping @MainActor (Item) -> Presented
    ) -> ItemSheetView<Self, Item, Presented> {
        sheet(
            item: item, dismissalPolicy: dismissalPolicy, onDismiss: onDismiss,
            content: { item, _ in return content(item) })
    }

    /// Supplies payload content with a dismiss action revoked on replacement or dismissal.
    /// The lifecycle hook runs once when the presentation ends, not on payload updates.
    public func sheet<Item: Identifiable, Presented: View>(
        item: Binding<Item?>, dismissalPolicy: SheetDismissalPolicy = .escape,
        onDismiss: @escaping @MainActor () -> Void = {},
        @ViewBuilder content: @escaping @MainActor (Item, DismissAction) -> Presented
    ) -> ItemSheetView<Self, Item, Presented> {
        ItemSheetView(
            content: self, item: item, dismissalPolicy: dismissalPolicy,
            onDismiss: onDismiss, presentedContent: content)
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
            SheetDescription(
                base: content, isPresented: isPresented,
                identity: { item.wrappedValue.map { AnyHashable($0.id) } }, dismissalPolicy: dismissalPolicy,
                onDismiss: onDismiss,
                content: { dismiss in
                    ItemSheetContent(item: item.wrappedValue, dismiss: dismiss, presentedContent: presentedContent)
                }))
    }
}

/// Keying inside the existing sheet keeps the base and modal focus scope stable.
private struct ItemSheetContent<Item: Identifiable, Presented: View>: View {
    let item: Item?
    let dismiss: DismissAction
    let presentedContent: @MainActor (Item, DismissAction) -> Presented
    @ViewBuilder var body: some View {
        if let item { presentedContent(item, dismiss).id(item.id) }
    }
}

/// Presents a separate keyboard scope while retaining the underlying mounted view.
public struct SheetView<Content: View, Presented: View>: View {
    /// Primitive content rendered directly by the runtime.
    public typealias Body = Never
    private let content: Content
    private let isPresented: Binding<Bool>
    private let dismissalPolicy: SheetDismissalPolicy
    private let onDismiss: @MainActor () -> Void
    private let presentedContent: @MainActor (DismissAction) -> Presented

    init(
        content: Content, isPresented: Binding<Bool>, dismissalPolicy: SheetDismissalPolicy,
        onDismiss: @escaping @MainActor () -> Void, presentedContent: @escaping @MainActor (DismissAction) -> Presented
    ) {
        self.content = content
        self.isPresented = isPresented
        self.dismissalPolicy = dismissalPolicy
        self.onDismiss = onDismiss
        self.presentedContent = presentedContent
    }
}

extension View {
    /// Presents a modal scope. Unhandled Escape dismisses by default.
    /// The lifecycle hook runs once after presented content is removed, including parent removal.
    public func sheet<Presented: View>(
        isPresented: Binding<Bool>, dismissalPolicy: SheetDismissalPolicy = .escape,
        onDismiss: @escaping @MainActor () -> Void = {},
        @ViewBuilder content: @escaping @MainActor () -> Presented
    ) -> SheetView<Self, Presented> {
        sheet(
            isPresented: isPresented, dismissalPolicy: dismissalPolicy, onDismiss: onDismiss,
            content: { _ in return content() })
    }

    /// Supplies an action scoped to this presentation. Stale actions cannot dismiss later content.
    public func sheet<Presented: View>(
        isPresented: Binding<Bool>, dismissalPolicy: SheetDismissalPolicy = .escape,
        onDismiss: @escaping @MainActor () -> Void = {},
        @ViewBuilder content: @escaping @MainActor (DismissAction) -> Presented
    ) -> SheetView<Self, Presented> {
        SheetView(
            content: self, isPresented: isPresented, dismissalPolicy: dismissalPolicy,
            onDismiss: onDismiss, presentedContent: content)
    }
}

extension SheetView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .sheet(
            SheetDescription(
                base: content, isPresented: isPresented, identity: nil,
                dismissalPolicy: dismissalPolicy, onDismiss: onDismiss, content: { presentedContent($0) }))
    }
}

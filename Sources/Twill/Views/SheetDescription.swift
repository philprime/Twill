/// Presentation callbacks are independent of the concrete base and content builders.
struct SheetDescription {
    let base: any View
    let isPresented: Binding<Bool>
    let identity: @MainActor () -> AnyHashable?
    let dismissalPolicy: SheetDismissalPolicy
    let onDismiss: @MainActor () -> Void
    let content: @MainActor (DismissAction) -> any View
}

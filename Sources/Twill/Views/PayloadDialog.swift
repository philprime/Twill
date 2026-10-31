extension View {
    /// Payload identity and scoped dismissal stay in the shared sheet lifetime.
    func payloadDialog<Item: Identifiable, Actions: View, Message: View>(
        _ dialog: (title: String, kind: DialogKind), item: Binding<Item?>,
        onDismiss: @escaping @MainActor () -> Void,
        actions: @escaping @MainActor (Item) -> Actions, message: @escaping @MainActor (Item) -> Message
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { payload, dismiss in
            let isPresented = Binding(
                get: { item.wrappedValue != nil },
                set: { presented in
                    if !presented { dismiss() }
                })
            return DialogView(
                title: dialog.title, actions: actions(payload), message: message(payload),
                isPresented: isPresented, kind: dialog.kind)
        }
    }
}

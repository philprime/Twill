extension View {
    /// Presents a modal choice with a Cancel action unless an enabled one is supplied.
    /// Cancellation receives initial focus so a destructive operation requires
    /// deliberate navigation. Every action dismisses the dialog after running.
    public func confirmationDialog<Actions: View, Message: View>(
        _ title: String, isPresented: Binding<Bool>,
        @ViewBuilder actions: @escaping @MainActor () -> Actions,
        @ViewBuilder message: @escaping @MainActor () -> Message
    ) -> some View {
        sheet(isPresented: isPresented) {
            DialogView(
                title: title, actions: actions(), message: message(), isPresented: isPresented, kind: .confirmation)
        }
    }

    /// Presents choices without a message, initially focusing cancellation. Each action dismisses the dialog.
    public func confirmationDialog<Actions: View>(
        _ title: String, isPresented: Binding<Bool>,
        @ViewBuilder actions: @escaping @MainActor () -> Actions
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, actions: actions, message: { return EmptyView() })
    }
}

extension View {
    /// Presents an identifiable payload using shared dialog roles and sheet identity.
    /// Updated values with the same ID retain state; actions dismiss after running.
    public func confirmationDialog<Item: Identifiable, Actions: View, Message: View>(
        _ title: String, item: Binding<Item?>, onDismiss: @escaping @MainActor () -> Void = {},
        @ViewBuilder actions: @escaping @MainActor (Item) -> Actions,
        @ViewBuilder message: @escaping @MainActor (Item) -> Message
    ) -> some View {
        payloadDialog((title, .confirmation), item: item, onDismiss: onDismiss, actions: actions, message: message)
    }

    /// Presents payload actions without a message using the ordinary dialog policy.
    public func confirmationDialog<Item: Identifiable, Actions: View>(
        _ title: String, item: Binding<Item?>, onDismiss: @escaping @MainActor () -> Void = {},
        @ViewBuilder actions: @escaping @MainActor (Item) -> Actions
    ) -> some View {
        confirmationDialog(
            title, item: item, onDismiss: onDismiss, actions: actions, message: { _ in return EmptyView() })
    }
}

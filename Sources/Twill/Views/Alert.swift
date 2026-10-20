extension View {
    /// Presents a titled message and actions in a modal sheet. Actions dismiss the
    /// alert after running. Escape invokes the cancel action, or simply dismisses.
    /// An alert with no actions supplies an OK button.
    public func alert<Actions: View, Message: View>(
        _ title: String, isPresented: Binding<Bool>,
        @ViewBuilder actions: @escaping @MainActor () -> Actions,
        @ViewBuilder message: @escaping @MainActor () -> Message
    ) -> some View {
        sheet(isPresented: isPresented) {
            DialogView(title: title, actions: actions(), message: message(), isPresented: isPresented, kind: .alert)
        }
    }

    /// Presents an alert without a message. Actions dismiss it after running; Escape cancels or dismisses.
    public func alert<Actions: View>(
        _ title: String, isPresented: Binding<Bool>,
        @ViewBuilder actions: @escaping @MainActor () -> Actions
    ) -> some View {
        alert(title, isPresented: isPresented, actions: actions, message: { return EmptyView() })
    }
}

extension View {
    /// Presents an identifiable payload using shared dialog roles and sheet identity.
    /// Updated values with the same ID retain state; actions dismiss after running.
    public func alert<Item: Identifiable, Actions: View, Message: View>(
        _ title: String, item: Binding<Item?>, onDismiss: @escaping @MainActor () -> Void = {},
        @ViewBuilder actions: @escaping @MainActor (Item) -> Actions,
        @ViewBuilder message: @escaping @MainActor (Item) -> Message
    ) -> some View {
        payloadDialog((title, .alert), item: item, onDismiss: onDismiss, actions: actions, message: message)
    }

    /// Presents payload actions without a message using the ordinary dialog policy.
    public func alert<Item: Identifiable, Actions: View>(
        _ title: String, item: Binding<Item?>, onDismiss: @escaping @MainActor () -> Void = {},
        @ViewBuilder actions: @escaping @MainActor (Item) -> Actions
    ) -> some View {
        alert(title, item: item, onDismiss: onDismiss, actions: actions, message: { _ in return EmptyView() })
    }
}

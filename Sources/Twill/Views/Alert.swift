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

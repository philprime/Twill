extension View {
    /// Presents a modal choice with a Cancel action unless one is supplied.
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

/// The shared layout for modal messages. The sheet owns focus and presentation.
struct DialogView<Actions: View, Message: View>: View {
    let title: String
    let actions: Actions
    let message: Message
    let isPresented: Binding<Bool>
    let kind: DialogKind

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 1) {
                message
                DialogActions(actions: actions, isPresented: isPresented, kind: kind)
            }
            .padding(.horizontal)
        }
    }
}

import Twill

struct HelpView: View {
    let onDismiss: @MainActor () -> Void

    var body: some View {
        Text("Help: Esc closes this overlay")
            .focusable()
            .onKeyPress { key in
                guard key == .escape else { return .ignored }
                onDismiss()
                return .handled
            }
    }
}

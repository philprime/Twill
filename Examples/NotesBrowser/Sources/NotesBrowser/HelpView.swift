import Twill

struct HelpView: View {
    let onDismiss: @MainActor () -> Void

    var body: some View {
        VStack {
            Text("Help")
            Text("Arrows: focus | Enter: select/edit")
            Text("Esc: stop editing / close help")
            Text("s: toggle summary | ?: help")
        }
        .focusable()
        .onKeyPress { key in
            guard key == .escape else { return .ignored }
            onDismiss()
            return .handled
        }
    }
}

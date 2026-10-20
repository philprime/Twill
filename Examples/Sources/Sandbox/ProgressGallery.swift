import Twill

struct ProgressGallery: View {
    @State private var completed = 2
    @State private var isLoading = true
    private let total = 8

    var body: some View {
        GroupBox("Progress") {
            VStack(alignment: .leading, spacing: 1) {
                ProgressView("Files \(completed)/\(total)", value: Double(completed), total: Double(total))
                Stepper("Completed", value: $completed, in: 0...total, format: { "\($0)/\(total) files" })
                Slider(
                    "Completed files",
                    value: Binding(get: { Double(completed) }, set: { completed = Int($0) }),
                    in: 0...Double(total), step: 1, format: { "\(Int($0))/\(total) files" })
                Text("←/→: adjust  •  ↑/↓: focus  •  Home/End: slider bounds")
                HStack(spacing: 2) {
                    Button("Reset") { completed = 0 }
                    Button(isLoading ? "Stop spinner" : "Start spinner") { isLoading.toggle() }
                }
                if isLoading {
                    HStack(spacing: 3) {
                        ProgressView("Dots")
                        ProgressView("Arc", spinnerStyle: .arc)
                        ProgressView("Line", spinnerStyle: .line)
                        ProgressView("Custom", spinnerStyle: .custom(.init(["○", "◔", "◑", "◕", "●"])))
                    }
                } else {
                    Text("Idle")
                }
            }
            .padding(.horizontal)
        }
        .frame(width: 60)
        .controlStyle(GalleryControlStyle())
    }
}

private struct GalleryControlStyle: ControlStyle {
    func resolve(_ state: ControlState, in theme: Theme) -> ControlAppearance {
        var attributes: TextAttributes = []
        if !state.isEnabled { attributes.insert(.dim) }
        if state.isFocused { attributes.insert(.bold) }
        if state.isSelected { attributes.insert(.underline) }
        return ControlAppearance(
            foreground: state.isFocused ? SemanticColor.accent : nil,
            attributes: attributes, focusEffect: .none)
    }
}

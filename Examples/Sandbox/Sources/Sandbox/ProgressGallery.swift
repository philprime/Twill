import Twill

struct ProgressGallery: View {
    @State private var completed = 2
    @State private var isLoading = true
    private let total = 8

    var body: some View {
        GroupBox("Progress") {
            VStack(alignment: .leading, spacing: 1) {
                ProgressView("Files \(completed)/\(total)", value: Double(completed), total: Double(total))
                Stepper("Completed files", value: $completed, in: 0...total)
                Text("Left/Right: adjust  •  Up/Down: move focus")
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
    }
}

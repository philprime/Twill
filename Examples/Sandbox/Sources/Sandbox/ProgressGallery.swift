import Twill

struct ProgressGallery: View {
    @State private var completed = 2
    @State private var isLoading = true
    private let total = 8

    var body: some View {
        GroupBox("Progress") {
            VStack(alignment: .leading, spacing: 1) {
                ProgressView("Files \(completed)/\(total)", value: Double(completed), total: Double(total))
                HStack(spacing: 2) {
                    Button("Advance") { completed = min(completed + 1, total) }
                    Button("Reset") { completed = 0 }
                    Button(isLoading ? "Stop spinner" : "Start spinner") { isLoading.toggle() }
                }
                if isLoading {
                    ProgressView("Waiting for work")
                } else {
                    Text("Idle")
                }
            }
            .padding(.horizontal)
        }
        .frame(width: 60)
    }
}

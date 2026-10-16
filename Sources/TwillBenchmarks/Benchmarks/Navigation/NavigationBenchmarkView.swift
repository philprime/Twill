import Twill

struct NavigationBenchmarkView: View {
    @State private var selection: Int? = 0
    @State private var query = ""
    let onSelection: @MainActor () -> Void
    private let rows = Array(0..<24)

    var body: some View {
        VStack {
            Text("Notes navigation benchmark")
                .frame(maxWidth: .infinity, alignment: .leading)
                .backgroundStyle(Color(red: 94, green: 205, blue: 237))
            GroupBox("Search") {
                ScrollView {
                    TextField("Search titles and bodies", text: $query)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 1)
            }
            HStack(spacing: 2) {
                GroupBox("Notes") {
                    List(
                        rows, id: \.self,
                        selection: Binding(
                            get: { selection },
                            set: {
                                selection = $0
                                onSelection()
                            })
                    ) { row in
                        VStack(alignment: .leading) {
                            Text("Note \(row)")
                            Text("A short summary of this note")
                                .frame(width: 22, alignment: .leading)
                        }
                    }
                    .frame(width: 26)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                GroupBox("Preview") {
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Note \(selection ?? 0)")
                            ForEach(0..<8, id: \.self) { line in
                                Text("Preview line \(line) for note \(selection ?? 0)")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text("Tab: pane | Arrows: select")
        }
    }
}

import Foundation
import Twill

/// Synthetic SDK fixture with nested layout, sortable columns, and two keyboard panes.
/// Its data never depends on running processes or the example executables.
struct TableBenchmarkView: View {
    struct Row: Identifiable {
        let id: Int
        let name: String
        let usage: Int
    }

    let rows: [Row]
    let selection: Binding<Int?>
    let revision: Int
    @State private var query = ""
    @State private var sortOrder: [KeyPathComparator<Row>] = []

    var body: some View {
        VStack(alignment: .leading) {
            Text("Synthetic dashboard \(revision)")
            HStack {
                GroupBox("Load") { Text("42%").frame(maxWidth: .infinity) }
                GroupBox("Memory") { Text("8 GiB").frame(maxWidth: .infinity) }
            }
            ScrollView {
                TextField("Filter", text: $query).frame(maxWidth: .infinity)
            }
            .frame(height: 1)
            GroupBox("Records") {
                Table(rows, selection: selection, sortOrder: $sortOrder) {
                    TableColumn("ID", value: \.id) { Text(String($0.id)) }
                    TableColumn("Usage", value: \.usage) { Text(String($0.usage)) }
                    TableColumn("Memory") { Text("\($0.usage) MiB") }
                    TableColumn("Status") { _ in Text("Running") }
                    TableColumn("Name", value: \.name)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text("Selected: \(selection.wrappedValue ?? 0)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

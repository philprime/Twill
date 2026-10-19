import Twill
import TwillGraphs

struct PackageExplorerView: View {
    let package: LoadedPackage
    @State private var selected: String?
    @State private var query = ""
    @State private var module = "All modules"
    @State private var kind = "All types"
    @FocusState private var searchFocused: Bool

    var body: some View {
        let graph = package.graph.filtered(
            query: query, module: module == "All modules" ? nil : module, kind: PackageTypeKind(rawValue: kind))
        let selectedID = graph.nodes.first { $0.id == selected }?.id ?? graph.nodes.first?.id
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(package.name) · \(graph.nodes.count) types · \(graph.edges.count) relationships")
            TextField("Search types", text: $query).focused($searchFocused)
            Picker("Module", selection: $module, options: ["All modules"] + package.graph.modules) { Text($0) }
            Picker("Kind", selection: $kind, options: ["All types"] + PackageTypeKind.allCases.map(\.rawValue)) {
                Text($0)
            }
            HStack(alignment: .top, spacing: 1) {
                GraphView(graph, positions: package.positions, selection: $selected)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                PackageTypeInspector(graph: package.graph, selected: selectedID).frame(width: 36)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("/: search · Tab: focus · Arrows: select · +/-: zoom · WASD: pan · 0: fit · Ctrl-C: quit")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onKeyPress { key in
            guard key == .character("/") else { return .ignored }
            searchFocused = true
            return .handled
        }
    }
}

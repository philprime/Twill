import Twill

struct PackageTypeInspector: View {
    let graph: PackageGraph
    let selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selected, let type = graph.types[selected] {
                Text(type.name).foregroundStyle(Color.cyan)
                Text("\(type.kind.rawValue) · \(type.module)")
                Text(type.declaration)
                if let source = type.source {
                    Text("\(source.lastPathComponent):\(type.line ?? 1)")
                }
                Text("")
                Text("Relationships")
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(
                            Array(
                                graph.relationships.filter { $0.source == selected || $0.target == selected }
                                    .enumerated()), id: \.offset
                        ) { item in
                            if item.element.source == selected {
                                Text("\(item.element.kind.label) → \(graph.types[item.element.target]?.name ?? "")")
                            } else if item.element.target == selected {
                                Text("← \(graph.types[item.element.source]?.name ?? "")")
                            }
                        }
                    }
                }.frame(maxHeight: .infinity)
            } else {
                Text("No matching types")
            }
        }.frame(maxHeight: .infinity)
    }
}

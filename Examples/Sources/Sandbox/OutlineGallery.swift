import Twill

struct OutlineGallery: View {
    private struct Resource: Identifiable {
        let id: String
        let name: String
        var children: [Resource]?
    }

    @State private var selection: String?
    @State private var expandedIDs: Set<String> = ["Sources"]
    @State private var opened = "No resource opened"

    private let resources = [
        Resource(
            id: "Sources", name: "Sources",
            children: [
                Resource(
                    id: "Sources/App", name: "App",
                    children: [
                        Resource(id: "Sources/App/Main.swift", name: "Main.swift"),
                        Resource(id: "Sources/App/ContentView.swift", name: "ContentView.swift"),
                    ]),
                Resource(id: "Sources/Library", name: "Library (empty)", children: []),
            ]),
        Resource(
            id: "Tests", name: "Tests",
            children: [Resource(id: "Tests/AppTests.swift", name: "AppTests.swift")]),
        Resource(id: "Package.swift", name: "Package.swift"),
    ]

    var body: some View {
        VStack(alignment: .leading) {
            OutlineGroup(resources, children: \.children, selection: $selection, expandedIDs: $expandedIDs) {
                Text($0.name)
            }
            .frame(width: 36, height: 5)
            .onSubmit { opened = selection ?? "No resource opened" }
            Text("Opened: \(opened)")
            Text("Up/Down: select · Right: expand/enter · Left: collapse/parent · Enter: open")
        }
    }
}

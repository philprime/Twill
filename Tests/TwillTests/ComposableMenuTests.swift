import Testing

@testable import Twill

@Suite("Composable menu actions")
@MainActor
struct ComposableMenuTests {
    @Test("Typed custom labels open ordinary button content and restore the opener")
    func customLabel() throws {
        // -- Arrange --
        var actions = 0
        let menu: Menu<Text, Button<Text>> = Menu(
            content: { return Button("Run") { actions += 1 } },
            label: { return Text("Open") })
        let renderer = ViewRenderer.make(menu)
        let closed = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.enter)
        let open = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        let restored = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(closed.snapshotText == "Open" && open.snapshotText.contains("Run"))
        #expect(restored.snapshotText == "Open" && actions == 1)
    }

    @Test("Ordinary buttons share shortcut hints, disabled eligibility and action dismissal")
    func buttonMetadata() throws {
        // -- Arrange --
        var actions: [String] = []
        let renderer = ViewRenderer.make(
            Menu("Actions") {
                Button("Run") { actions.append("run") }.keyboardShortcut(.r)
                Button("Stop", role: .destructive) { actions.append("disabled") }.keyboardShortcut(.s).disabled(true)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        let open = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.s)
        _ = renderer.handle(.r)
        let closed = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(open.snapshotText.contains("Run  [r]"))
        #expect(open.snapshotText.contains("Stop  [s] (disabled)"))
        #expect(actions == ["run"] && closed.snapshotText == "Actions")
    }

    @Test("Label handlers keep first refusal while shortcut activation uses the shared action path")
    func labelHandlerOrder() throws {
        // -- Arrange --
        var events: [String] = []
        let renderer = ViewRenderer.make(
            Menu("Actions") {
                Button(
                    action: { events.append("action") },
                    label: {
                        Text("Run").onKeyPress { key in
                            guard key == .enter else { return .ignored }
                            events.append("label")
                            return .handled
                        }
                    }
                ).keyboardShortcut(.r)
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        let stillOpen = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.r)
        let closed = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(stillOpen.snapshotText.contains("Run"))
        #expect(events == ["label", "action"] && closed.snapshotText == "Actions")
    }

    @Test("A shortcut on a multi-action container does not become either button's hint or action")
    func ambiguousContainerShortcut() throws {
        // -- Arrange --
        var actions = 0
        let renderer = ViewRenderer.make(
            Menu("Actions") {
                Group {
                    Button("One") { actions += 1 }
                    Button("Two") { actions += 1 }
                }.keyboardShortcut(.q)
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        let open = try #require(renderer.render(.now).grid)

        // -- Act --
        _ = renderer.handle(.q)

        // -- Assert --
        #expect(!open.snapshotText.contains("[q]"))
        #expect(actions == 0)
    }

    private struct Dynamic: View {
        @State private var rows = ["A", "B"]
        let capture: (Binding<[String]>) -> Void
        let action: (String) -> Void
        var body: some View {
            capture($rows)
            return Menu("Actions") {
                ForEach(rows, id: \.self) { value in Button(value) { action(value) } }
            }
        }
    }

    @Test("Dynamic builder rows retain keyed identity and focus while presented")
    func dynamicRows() throws {
        // -- Arrange --
        var rows: Binding<[String]>?
        var actions: [String] = []
        let renderer = ViewRenderer.make(Dynamic(capture: { rows = $0 }, action: { actions.append($0) }))
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        weak var retained: ViewRenderer?
        retained = renderer.keyedNode(for: "B")

        // -- Act --
        rows?.wrappedValue = ["B", "C"]
        let updated = try #require(renderer.render(.now).grid)
        let sameNode = retained != nil && retained === renderer.keyedNode(for: "B")
        _ = renderer.handle(.enter)
        let closed = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(sameNode && updated.snapshotText.contains("C"))
        #expect(actions == ["B"] && closed.snapshotText == "Actions")
    }
}

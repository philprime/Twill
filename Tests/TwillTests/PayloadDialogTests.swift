import Testing

@testable import Twill

@Suite("Payload-driven dialogs")
@MainActor
struct PayloadDialogTests {
    private struct Payload: Identifiable {
        let id: Int
        let title: String
    }

    @Test("Alerts deliver updated payloads to messages and actions and clear the item once")
    func freshPayload() throws {
        // -- Arrange --
        var item: Payload? = Payload(id: 1, title: "One")
        var actions: [String] = []
        var callbacks = 0
        func content() -> some View {
            Text("Base").alert(
                "Notice", item: Binding(get: { item }, set: { item = $0 }),
                onDismiss: { callbacks += 1 },
                actions: { payload in
                    Button("Accept \(payload.title)") { actions.append(payload.title) }
                }, message: { payload in Text("Message \(payload.title)") })
        }
        let renderer = ViewRenderer.make(content())
        _ = renderer.render(.now)

        // -- Act --
        item = Payload(id: 1, title: "Updated")
        renderer.update(content(), at: .now)
        let updated = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        renderer.unmount()

        // -- Assert --
        #expect(updated.snapshotText.contains("Message Updated") && updated.snapshotText.contains("Accept Updated"))
        #expect(actions == ["Updated"] && item == nil && callbacks == 1)
    }

    @Test("Confirmation replacement resets deliberate focus to cancellation")
    func deliberateFocus() {
        // -- Arrange --
        var item: Payload? = Payload(id: 1, title: "One")
        var actions: [String] = []
        func content() -> some View {
            Text("Base").confirmationDialog("Delete?", item: Binding(get: { item }, set: { item = $0 })) { payload in
                Button("Delete", role: .destructive) { actions.append("delete:\(payload.title)") }
                Button("Keep", role: .cancel) { actions.append("keep:\(payload.title)") }
            }
        }
        let renderer = ViewRenderer.make(content())
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowUp)

        // -- Act --
        item = Payload(id: 2, title: "Next")
        renderer.update(content(), at: .now)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(actions == ["keep:Next"] && item == nil)
    }

    @Test("An action replacing the payload cannot dismiss its replacement before reconciliation")
    func actionReplacement() throws {
        // -- Arrange --
        var item: Payload? = Payload(id: 1, title: "One")
        var callbacks = 0
        let renderer = ViewRenderer.make(
            Text("Base").alert(
                "Choose", item: Binding(get: { item }, set: { item = $0 }),
                onDismiss: { callbacks += 1 },
                actions: { _ in
                    Button("Replace") { item = Payload(id: 2, title: "Next") }
                }, message: { payload in Text(payload.title) }))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        let replacement = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(item?.id == 2 && callbacks == 0)
        #expect(replacement.snapshotText.contains("Next"))
    }

    @Test("Empty payload alerts and confirmations reuse fallback actions")
    func fallbackActions() throws {
        // -- Arrange --
        var alertItem: Payload? = Payload(id: 1, title: "Alert")
        var confirmItem: Payload? = Payload(id: 2, title: "Confirm")
        let alert = ViewRenderer.make(
            Text("Base").alert("Notice", item: Binding(get: { alertItem }, set: { alertItem = $0 })) { _ in })
        let confirmBinding = Binding(get: { confirmItem }, set: { confirmItem = $0 })
        let confirm = ViewRenderer.make(Text("Base").confirmationDialog("Choose", item: confirmBinding) { _ in })
        let alertGrid = try #require(alert.render(.now).grid)
        let confirmGrid = try #require(confirm.render(.now).grid)

        // -- Act --
        _ = alert.handle(.enter)
        _ = confirm.handle(.escape)
        _ = alert.render(.now)
        _ = confirm.render(.now)

        // -- Assert --
        #expect(alertGrid.snapshotText.contains("OK") && confirmGrid.snapshotText.contains("Cancel"))
        #expect(alertItem == nil && confirmItem == nil)
    }

    @Test("Disabled actions cannot activate and confirmation still supplies eligible cancellation")
    func disabledActions() {
        // -- Arrange --
        var item: Payload? = Payload(id: 1, title: "One")
        var actions = 0
        let renderer = ViewRenderer.make(
            Text("Base").confirmationDialog("Choose", item: Binding(get: { item }, set: { item = $0 })) { _ in
                Button("Delete", role: .destructive) { actions += 1 }.disabled(true)
                Button("Unavailable cancel", role: .cancel) { actions += 1 }.disabled(true)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(item == nil && actions == 0)
    }

    @Test("Ordinary actions and Escape cancellation receive the current payload")
    func actionRoles() {
        // -- Arrange --
        var item: Payload? = Payload(id: 1, title: "One")
        var actions: [String] = []
        func content() -> some View {
            Text("Base").alert("Choose", item: Binding(get: { item }, set: { item = $0 })) { payload in
                Button("Ordinary") { actions.append("ordinary") }
                Button("Default") { actions.append("default:\(payload.title)") }
                Button("Cancel", role: .cancel) { actions.append("cancel:\(payload.title)") }
            }
        }
        let renderer = ViewRenderer.make(content())
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowUp)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        item = Payload(id: 2, title: "Next")
        renderer.update(content(), at: .now)
        _ = renderer.render(.now)
        _ = renderer.handle(.escape)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(actions == ["default:One", "cancel:Next"] && item == nil)
    }

    private struct StatefulChoice: View {
        @State private var checked = false
        let capture: (Binding<Bool>) -> Void
        var body: some View {
            capture($checked)
            return Toggle("Flag", isOn: $checked)
        }
    }

    @Test("Matching IDs retain action state and replacements start a fresh subtree")
    func stateIdentity() throws {
        // -- Arrange --
        var item: Payload? = Payload(id: 1, title: "One")
        var checked: Binding<Bool>?
        func content() -> some View {
            Text("Base").alert("Choose", item: Binding(get: { item }, set: { item = $0 })) { _ in
                StatefulChoice(capture: { checked = $0 })
            }
        }
        let renderer = ViewRenderer.make(content())
        _ = renderer.render(.now)
        checked?.wrappedValue = true
        _ = renderer.render(.now)

        // -- Act --
        item = Payload(id: 1, title: "Updated")
        renderer.update(content(), at: .now)
        _ = renderer.render(.now)
        let retained = checked?.wrappedValue
        item = Payload(id: 2, title: "Next")
        renderer.update(content(), at: .now)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(retained == true && checked?.wrappedValue == false)
    }

    @Test("Nil payloads do not evaluate action or message builders")
    func absentPayload() throws {
        // -- Arrange --
        var builds = 0
        let renderer = ViewRenderer.make(
            Text("Base").alert(
                "Notice", item: Binding<Payload?>.constant(nil),
                actions: { _ in
                    builds += 1
                    return Button("Accept") {}
                },
                message: { _ in
                    builds += 1
                    return Text("Message")
                }))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "Base" && builds == 0)
    }
}

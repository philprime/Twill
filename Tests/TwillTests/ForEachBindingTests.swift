import Foundation
import Testing

@testable import Twill

@Suite("Editable keyed collections")
@MainActor
struct ForEachBindingTests {
    private struct Item: Identifiable {
        let id: String
        var label: String
    }

    private struct Entry {
        let key: String
        var label: String
    }

    private struct Row: View {
        @Binding var item: Item
        @State private var edits = 0

        var body: some View {
            Button("\(item.label):\(edits)") {
                item.label += "!"
                edits += 1
            }
        }
    }

    private struct Parent: View {
        @State private var items = [Item(id: "a", label: "Alpha"), Item(id: "b", label: "Beta")]
        let captureCollection: @MainActor (Binding<[Item]>) -> Void
        let captureRow: @MainActor (String, Binding<Item>) -> Void

        var body: some View {
            captureCollection($items)
            return VStack(alignment: .leading) {
                ForEach($items) { item in
                    row(item)
                }
            }
        }

        private func row(_ binding: Binding<Item>) -> Row {
            captureRow(binding.wrappedValue.id, binding)
            return Row(item: binding)
        }
    }

    @Test("Retained row bindings follow stable IDs and preserve row state after reordering")
    func reordering() throws {
        // -- Arrange --
        var collection: Binding<[Item]>?
        var rows: [String: Binding<Item>] = [:]
        let renderer = ViewRenderer.make(
            Parent(captureCollection: { collection = $0 }, captureRow: { rows[$0] = $1 }))
        _ = renderer.render(.now)
        let items = try #require(collection)
        let alpha = try #require(rows["a"])
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        items.wrappedValue.reverse()
        alpha.label.wrappedValue = "Edited"
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(items.wrappedValue.map(\.id) == ["b", "a"])
        #expect(items.wrappedValue.map(\.label) == ["Beta", "Edited"])
        #expect(
            frame.snapshotText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) } == [
                "Beta:0", "Edited:1",
            ])
    }

    @Test("Insertion and removal of other rows do not retarget a retained binding")
    func structuralEdits() throws {
        // -- Arrange --
        var collection: Binding<[Item]>?
        var rows: [String: Binding<Item>] = [:]
        let renderer = ViewRenderer.make(
            Parent(captureCollection: { collection = $0 }, captureRow: { rows[$0] = $1 }))
        _ = renderer.render(.now)
        let items = try #require(collection)
        let beta = try #require(rows["b"])

        // -- Act --
        items.wrappedValue.removeFirst()
        items.wrappedValue.insert(Item(id: "c", label: "Gamma"), at: 0)
        beta.label.wrappedValue = "Edited"
        _ = renderer.render(.now)

        // -- Assert --
        #expect(items.wrappedValue.map(\.id) == ["c", "b"])
        #expect(items.wrappedValue.map(\.label) == ["Gamma", "Edited"])
    }

    @Test("Row bindings read external replacements with the same ID")
    func externalReplacement() throws {
        // -- Arrange --
        var collection: Binding<[Item]>?
        var rows: [String: Binding<Item>] = [:]
        let renderer = ViewRenderer.make(
            Parent(captureCollection: { collection = $0 }, captureRow: { rows[$0] = $1 }))
        _ = renderer.render(.now)
        let items = try #require(collection)
        let alpha = try #require(rows["a"])

        // -- Act --
        items.wrappedValue[0] = Item(id: "a", label: "Replacement")

        // -- Assert --
        #expect(alpha.wrappedValue.label == "Replacement")
    }

    @Test("Removing all rows releases state before the collection is repopulated")
    func emptyCollection() throws {
        // -- Arrange --
        var collection: Binding<[Item]>?
        let renderer = ViewRenderer.make(
            Parent(captureCollection: { collection = $0 }, captureRow: { _, _ in }))
        _ = renderer.render(.now)
        let items = try #require(collection)
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)

        // -- Act --
        items.wrappedValue = []
        _ = renderer.render(.now)
        items.wrappedValue = [Item(id: "a", label: "Again")]
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(frame.snapshotText == "Again:0")
    }

    @Test("Explicit keys support editable non-Identifiable elements and projected closure parameters")
    func explicitKeys() {
        // -- Arrange --
        var entries = [Entry(key: "a", label: "Alpha"), Entry(key: "b", label: "Beta")]
        let binding = Binding(get: { entries }, set: { entries = $0 })
        let renderer = ViewRenderer.make(
            VStack {
                ForEach(binding, id: \.key) { @MainActor $entry in
                    TextField("Label", text: $entry.label)
                }
            })
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.x)

        // -- Assert --
        #expect(handled)
        #expect(entries.map(\.label) == ["Alphax", "Beta"])
    }

    @Test("A row edit requests presentation through its collection's state owner")
    func mountedInvalidation() throws {
        // -- Arrange --
        let runLoop = RecordingRunLoop()
        let output = RecordingTerminalOutput()
        var rows: [String: Binding<Item>] = [:]
        let host = ViewHost(
            rootView: Parent(captureCollection: { _ in }, captureRow: { rows[$0] = $1 }),
            runLoop: runLoop, output: output)
        try host.start()
        let alpha = try #require(rows["a"])
        let source = try #require(runLoop.sources.first)

        // -- Act --
        alpha.label.wrappedValue = "Edited"
        source.action()
        host.stop()

        // -- Assert --
        #expect(runLoop.signalled.count == 1)
        #expect(output.writes.joined().contains("Edited:0"))
    }
}

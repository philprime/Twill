import Foundation
import Testing

@testable import Twill

@Suite("Automatic keyboard traversal")
@MainActor
struct KeyboardTraversalTests {
    @Test("Fields, toggles and buttons participate in Tab traversal without wrappers")
    func ordinaryControls() {
        // -- Arrange --
        var text = ""
        var enabled = false
        var saves = 0
        let renderer = ViewRenderer.make(
            Form {
                TextField("Name", text: Binding(get: { text }, set: { text = $0 }))
                Toggle("Enabled", isOn: Binding(get: { enabled }, set: { enabled = $0 }))
                Button("Save") { saves += 1 }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.a)
        let first = renderer.handle(.tab)
        _ = renderer.handle(.space)
        let second = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        let end = renderer.handle(.tab)
        let backToToggle = renderer.handle(.shiftTab)
        let backToField = renderer.handle(.shiftTab)
        _ = renderer.handle(.b)
        let beginning = renderer.handle(.shiftTab)

        // -- Assert --
        #expect(first && second && backToToggle && backToField)
        #expect(!end && !beginning)
        #expect(text == "ab")
        #expect(enabled)
        #expect(saves == 1)
    }

    private struct Row: Identifiable {
        let id: Int
        let name: String
    }

    @Test("A sortable table is one Tab stop and restores its internal focused control")
    func compoundControl() {
        // -- Arrange --
        let rows = [Row(id: 1, name: "One"), Row(id: 2, name: "Two")]
        var selection: Int?
        var sortOrder = [KeyPathComparator(\Row.name)]
        var activations = 0
        var submissions = 0
        let renderer = ViewRenderer.make(
            VStack {
                Button("Before") {}
                Table(
                    rows, selection: Binding(get: { selection }, set: { selection = $0 }),
                    sortOrder: Binding(get: { sortOrder }, set: { sortOrder = $0 })
                ) {
                    TableColumn("Name", value: \.name)
                    TableColumn("ID", value: \.id) { Text("\($0.id)") }
                }
                .onSubmit { submissions += 1 }
                Button("After") { activations += 1 }
            })
        _ = renderer.render(.now)

        // -- Act --
        let entered = renderer.handle(.tab)
        _ = renderer.handle(.arrowDown)
        let left = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        let returned = renderer.handle(.shiftTab)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(entered && left && returned)
        #expect(activations == 1)
        #expect(submissions == 1)
        #expect(selection == 1)
    }

    @Test("Returning to a control resumes visibility after manual scrolling", arguments: [false, true])
    func returningControlRevealsFocus(reverse: Bool) throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Button("Before") {}
                ScrollView {
                    VStack {
                        Text("0").focusable()
                        Text("1").focusable()
                        Text("2").focusable()
                    }
                }.frame(height: 1)
                Button("After") {}
            })
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        if reverse {
            _ = renderer.handle(.tab)
            _ = renderer.handle(.tab)
        }
        _ = renderer.render(.now)
        #expect(renderer.handle(reverse ? .pageUp : .pageDown))
        let scrolled = try #require(renderer.render(.now).grid)
        #expect(scrolled.snapshotText.contains("1"))

        // -- Act --
        #expect(renderer.handle(reverse ? .tab : .shiftTab))
        _ = renderer.render(.now)
        #expect(renderer.handle(reverse ? .shiftTab : .tab))
        let returned = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(returned.snapshotText.contains(reverse ? "2" : "0"))
        #expect(returned.isFocused(column: 0, row: 1))
    }

    @Test("Tab traverses controls across plain viewports rather than treating viewports as groups")
    func viewportControls() {
        // -- Arrange --
        var activated: [String] = []
        let renderer = ViewRenderer.make(
            HStack {
                ScrollView {
                    VStack {
                        Button("A") { activated.append("A") }
                        Button("B") { activated.append("B") }
                    }
                }
                Button("C") { activated.append("C") }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.shiftTab)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(activated == ["B", "C", "B"])
    }
}

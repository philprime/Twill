import Testing

@testable import Twill

@Suite("Picker presentations and labels")
@MainActor
struct PickerPresentationTests {
    @Test("String conveniences retain inline output and expose compact and vertical layouts")
    func layouts() throws {
        // -- Arrange --
        let modes: [(PickerPresentation, String)] = [
            (.inline, "Mode: [ ] A [x] B [ ] C"),
            (.compact, "Mode: B"),
            (.vertical, "Mode:\n[ ] A\n[x] B\n[ ] C"),
        ]
        for (presentation, expected) in modes {
            let renderer = ViewRenderer.make(
                Picker(
                    "Mode", selection: .constant("B"), options: ["A", "B", "C"],
                    presentation: presentation))

            // -- Act --
            let grid = try #require(renderer.render(.now).grid)

            // -- Assert --
            #expect(grid.snapshotText == expected)
        }
    }

    @Test("Vertical arrows change selection while Tab still leaves the control")
    func verticalInteraction() {
        // -- Arrange --
        var selection = "A"
        var completed = 0
        let renderer = ViewRenderer.make(
            VStack {
                Picker(
                    "Mode", selection: Binding(get: { selection }, set: { selection = $0 }),
                    options: ["A", "B", "C"], presentation: .vertical)
                Button("Done") { completed += 1 }
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowDown)
        _ = renderer.render(.now)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(selection == "B")
        #expect(completed == 1)
    }

    @Test("All modes keep missing values until deliberate selection and empty options never write")
    func fallbackAndEmpty() throws {
        // -- Arrange --
        for mode in [PickerPresentation.inline, .compact, .vertical] {
            var selection = "missing"
            var writes = 0
            let binding = Binding(
                get: { selection },
                set: {
                    selection = $0
                    writes += 1
                })
            let populated = ViewRenderer.make(
                Picker("Mode", selection: binding, options: ["A", "B"], presentation: mode))
            let empty = ViewRenderer.make(Picker("Mode", selection: binding, options: [], presentation: mode))
            _ = populated.render(.now)
            let untouched = writes == 0 && selection == "missing"

            // -- Act --
            _ = populated.handle(.arrowRight)
            let selected = selection
            let blank = try #require(empty.render(.now).grid)
            _ = empty.handle(.arrowLeft)
            _ = empty.handle(.arrowRight)

            // -- Assert --
            #expect(untouched && selected == "B" && writes == 1)
            #expect(blank.snapshotText == "Mode:")
        }
    }

    @Test("Compact presentation evaluates only the effective option for large data")
    func largeCompactPicker() throws {
        // -- Arrange --
        var labels: [Int] = []
        let picker: Picker<Int, Text, Text> = Picker(
            selection: .constant(999), options: Array(0..<1000),
            presentation: .compact,
            content: { value in
                labels.append(value)
                return Text("\(value)")
            }, label: { return Text("Number:") })
        let renderer = ViewRenderer.make(picker)

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(labels == [999])
        #expect(grid.snapshotText == "Number: 999")
    }

    @Test("Custom control labels stay typed and own their punctuation")
    func customLabel() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Picker(selection: .constant("B"), options: ["A", "B"], presentation: .compact) {
                HStack {
                    Text("Sort").bold()
                    Text("mode")
                }
            })

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "Sort mode B")
        #expect(grid.attributes(column: 0, row: 0).contains(.bold))
    }

    @Test("Compact boundaries do not rewrite selection or intercept Enter")
    func compactBoundaries() {
        // -- Arrange --
        var writes = 0
        var entered = 0
        let renderer = ViewRenderer.make(
            Picker(
                "Mode", selection: Binding(get: { "A" }, set: { _ in writes += 1 }),
                options: ["A"], presentation: .compact
            ).onKeyPress { key in
                guard key == .enter else { return .ignored }
                entered += 1
                return .handled
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(writes == 0 && entered == 1)
    }
}

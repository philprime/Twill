import Testing

@testable import Twill

@Suite("Value observation lifetime")
@MainActor
struct ValueChangeLifetimeTests {
    private enum Page: Hashable { case first, second }
    private struct Tabs: View {
        @State private var page = Page.first
        @State private var value = 0
        let initial: Bool
        let surrounding: Bool
        let capture: (Binding<Page>, Binding<Int>) -> Void
        let callback: @MainActor (Int, Int) -> Void
        var body: some View {
            capture($page, $value)
            return TabView(selection: $page) {
                Tab("First", value: Page.first) { Text("First") }
                if surrounding {
                    Tab("Second", value: Page.second) { Text("Second") }
                        .onChange(of: value, initial: initial, callback)
                } else {
                    Tab("Second", value: Page.second) {
                        Text("Second").onChange(of: value, initial: initial, callback)
                    }
                }
            }
        }
    }

    @Test("Inactive retained branches defer/coalesce until activation without polling", arguments: [false, true])
    func inactiveBranches(initial: Bool) {
        // -- Arrange --
        var page: Binding<Page>?
        var value: Binding<Int>?
        var changes: [String] = []
        let renderer = ViewRenderer.make(
            Tabs(
                initial: initial, surrounding: false,
                capture: {
                    page = $0
                    value = $1
                },
                callback: {
                    changes.append("\($0):\($1)")
                }))
        let first = renderer.render(.now)

        // -- Act --
        value?.wrappedValue = 1
        _ = renderer.render(.now)
        value?.wrappedValue = 2
        let hidden = renderer.render(.now)
        let deferred = changes.isEmpty
        page?.wrappedValue = .second
        let activated = renderer.render(.now)

        // -- Assert --
        #expect(first.nextUpdate == nil && hidden.nextUpdate == nil && activated.nextUpdate == nil)
        #expect(deferred)
        #expect(changes == [initial ? "2:2" : "0:2"])
    }

    @Test("Observers surrounding inactive destinations use the same presentation eligibility")
    func surroundingInactiveTab() {
        // -- Arrange --
        var page: Binding<Page>?
        var value: Binding<Int>?
        var changes: [String] = []
        let renderer = ViewRenderer.make(
            Tabs(
                initial: false, surrounding: true,
                capture: {
                    page = $0
                    value = $1
                },
                callback: {
                    changes.append("\($0):\($1)")
                }))
        _ = renderer.render(.now)

        // -- Act --
        value?.wrappedValue = 1
        _ = renderer.render(.now)
        let deferred = changes.isEmpty
        page?.wrappedValue = .second
        _ = renderer.render(.now)

        // -- Assert --
        #expect(deferred && changes == ["0:1"])
    }

    private struct Change: Equatable {
        let old: Int?
        let new: Int?
    }

    @Test("Optional nil is a value rather than an uninitialized baseline")
    func optionalValues() {
        // -- Arrange --
        var changes: [Change] = []
        func content(_ value: Int?) -> some View {
            Text("Value").onChange(of: value, initial: true) { changes.append(Change(old: $0, new: $1)) }
        }
        let renderer = ViewRenderer.make(content(nil))
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content(nil), at: .now)
        _ = renderer.render(.now)
        renderer.update(content(1), at: .now)
        _ = renderer.render(.now)
        renderer.update(content(nil), at: .now)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(changes == [Change(old: nil, new: nil), Change(old: nil, new: 1), Change(old: 1, new: nil)])
    }

    private struct Probe: View {
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return Text("Sibling")
        }
    }

    @Test("Delivery follows the entire body/reconciliation pass, including later siblings")
    func afterBodies() {
        // -- Arrange --
        var events: [String] = []
        let renderer = ViewRenderer.make(
            VStack {
                Text("Observed").onChange(of: 1, initial: true) { _, _ in events.append("effect") }
                Probe(evaluated: { events.append("body") })
            })

        // -- Act --
        _ = renderer.render(.now)

        // -- Assert --
        #expect(events == ["body", "effect"])
    }

    private struct DerivedSheet: View {
        @State private var requested = false
        @State private var presented = false
        let callback: @MainActor (KeyEvent) -> Void
        var body: some View {
            Button("Open") { requested = true }
                .onChange(of: requested) { _, value in presented = value }
                .sheet(isPresented: $presented) {
                    Text("Modal").focusable().onKeyPress { key in
                        callback(key)
                        return .handled
                    }
                }
        }
    }

    @Test("A subsequent input key sees state derived by an observation before routing")
    func derivedModalScope() throws {
        // -- Arrange --
        var keys: [KeyEvent] = []
        let host = ViewHost(
            rootView: DerivedSheet(callback: { keys.append($0) }), runLoop: RecordingRunLoop(),
            output: RecordingTerminalOutput())
        try host.start()
        defer { host.stop() }

        // -- Act --
        _ = host.handle(.enter)
        let consumed = host.handle(.a)

        // -- Assert --
        #expect(consumed && keys == [.a])
    }

    @Test("Pending weak registrations do not retain removed owners")
    func weakOwner() {
        // -- Arrange --
        var callbacks = 0
        var renderer: ViewRenderer? = ViewRenderer.make(
            Text("Value").onChange(of: 1, initial: true) { _, _ in callbacks += 1 })
        weak var owner: ViewRenderer?
        owner = renderer
        renderer?.update(Text("Value").onChange(of: 2, initial: true) { _, _ in callbacks += 1 }, at: .now)

        // -- Act --
        renderer?.unmount()
        renderer = nil

        // -- Assert --
        #expect(owner == nil && callbacks == 0)
    }
}

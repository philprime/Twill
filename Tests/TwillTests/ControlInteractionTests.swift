import Testing

@testable import Twill

@Suite("Control interaction contract")
@MainActor
struct ControlInteractionTests {
    @MainActor
    private final class Events {
        var keys: [KeyEvent] = []
        var sizes: [CellSize] = []
        var blurs = 0
    }

    private struct ProbeControl: View, PrimitiveView {
        typealias Body = Never
        @State private var count = 0
        let events: Events
        var handlesDescendantKeys = false
        var submitsOnEnter = false

        func makeDescription() -> ViewDescription {
            let handle: @MainActor (KeyEvent, CellSize) -> KeyPressResult = { key, size in
                events.keys.append(key)
                events.sizes.append(size)
                guard key == .x else { return .ignored }
                count += 1
                return .handled
            }
            return .control(
                Text("Count \(count)").frame(width: 10, height: 2),
                ControlInteraction(
                    handleFocusedKey: handle,
                    handleDescendantKey: handlesDescendantKeys ? handle : nil,
                    blur: { events.blurs += 1 }, submitsOnEnter: submitsOnEnter))
        }
    }

    @Test("A composed control handles keys, reports measured size, and blurs once per transition")
    func composedControl() throws {
        // -- Arrange --
        let events = Events()
        var ancestorKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                ProbeControl(events: events)
                Button("Next") {}
            }.onKeyPress { key in
                guard key == .escape else { return .ignored }
                ancestorKeys.append(key)
                return .handled
            })
        let initial = try #require(renderer.render(.now).grid)

        // -- Act --
        let handled = renderer.handle(.x)
        let updated = try #require(renderer.render(.now).grid)
        let bubbled = renderer.handle(.escape)
        let moved = renderer.handle(.arrowDown)
        let next = try #require(renderer.render(.now).grid)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(handled && bubbled && moved)
        #expect(initial.snapshotText.contains("Count 0"))
        #expect(updated.snapshotText.contains("Count 1"))
        #expect(initial.isFocused(column: 2, row: 0))
        #expect(next.isFocused(column: 0, row: 2))
        #expect(events.keys == [.x, .escape, .arrowDown])
        #expect(events.sizes == Array(repeating: CellSize(width: 10, height: 2), count: 3))
        #expect(events.blurs == 1)
        #expect(ancestorKeys == [.escape])
    }

    @Test("Modifier-chain control handling is opt-in", arguments: [false, true])
    func descendantHandling(enabled: Bool) throws {
        // -- Arrange --
        let events = Events()
        var ancestorKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            ProbeControl(events: events, handlesDescendantKeys: enabled)
                .focusable()
                .onKeyPress { key in
                    ancestorKeys.append(key)
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.x)
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(handled)
        #expect(events.keys == (enabled ? [.x] : []))
        #expect(ancestorKeys == (enabled ? [] : [.x]))
        #expect(frame.snapshotText.contains(enabled ? "Count 1" : "Count 0"))
    }

    @Test("Focused control handling never visits a sibling control")
    func siblingIsolation() {
        // -- Arrange --
        let first = Events()
        let second = Events()
        let renderer = ViewRenderer.make(
            HStack {
                ProbeControl(events: first)
                ProbeControl(events: second)
            })
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.x)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.x)

        // -- Assert --
        #expect(first.keys == [.x, .arrowRight])
        #expect(second.keys == [.x])
        #expect(first.blurs == 1)
        #expect(second.blurs == 0)
    }

    @Test("Control submission fallback cannot escape a modal scope")
    func modalSubmission() {
        // -- Arrange --
        let events = Events()
        var outsideSubmits = 0
        let renderer = ViewRenderer.make(
            Text("Base")
                .sheet(isPresented: Binding(get: { true }, set: { _ in })) {
                    ProbeControl(events: events, submitsOnEnter: true)
                }
                .onSubmit { outsideSubmits += 1 })
        _ = renderer.render(.now)

        // -- Act --
        let trapped = renderer.handle(.enter)

        // -- Assert --
        #expect(trapped)
        #expect(events.keys == [.enter])
        #expect(outsideSubmits == 0)
    }

    @Test("Submission fallback is an explicit control policy", arguments: [false, true])
    func submissionFallback(enabled: Bool) {
        // -- Arrange --
        let events = Events()
        var submits = 0
        var bubbled: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            ProbeControl(events: events, submitsOnEnter: enabled)
                .onSubmit { submits += 1 }
                .onKeyPress { key in
                    bubbled.append(key)
                    return .handled
                })
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.enter)

        // -- Assert --
        #expect(handled)
        #expect(events.keys == [.enter])
        #expect(submits == (enabled ? 1 : 0))
        #expect(bubbled == (enabled ? [] : [.enter]))
    }
}

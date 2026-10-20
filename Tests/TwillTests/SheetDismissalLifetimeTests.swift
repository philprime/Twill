import Testing

@testable import Twill

@Suite("Sheet dismissal lifetime boundaries")
@MainActor
struct SheetDismissalLifetimeTests {
    private struct Payload: Identifiable { let id: Int }

    @Test("Payload replacement revokes old actions even when an earlier ID repeats")
    func payloadReplacement() {
        // -- Arrange --
        var item: Payload? = Payload(id: 1)
        var current: DismissAction?
        var callbacks = 0
        func content() -> some View {
            Text("Base").sheet(
                item: Binding(get: { item }, set: { item = $0 }), onDismiss: { callbacks += 1 },
                content: { _, dismiss in
                    current = dismiss
                    return Text("Modal")
                })
        }
        let renderer = ViewRenderer.make(content())
        _ = renderer.render(.now)
        let old = current
        item = Payload(id: 2)
        renderer.update(content(), at: .now)
        _ = renderer.render(.now)
        item = Payload(id: 1)
        renderer.update(content(), at: .now)
        _ = renderer.render(.now)

        // -- Act --
        old?()
        _ = renderer.render(.now)
        let retained = item != nil && callbacks == 0
        current?()
        _ = renderer.render(.now)

        // -- Assert --
        #expect(retained)
        #expect(item == nil && callbacks == 1)
    }

    @Test("Escape dismisses only the topmost sheet lifetime")
    func nestedEscape() {
        // -- Arrange --
        var outer = true
        var inner = true
        var callbacks: [String] = []
        let renderer = ViewRenderer.make(
            Text("Base").sheet(
                isPresented: Binding(get: { outer }, set: { outer = $0 }), onDismiss: { callbacks.append("outer") },
                content: {
                    Text("Outer").sheet(
                        isPresented: Binding(get: { inner }, set: { inner = $0 }),
                        onDismiss: { callbacks.append("inner") }, content: { Text("Inner") })
                }))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.escape)
        _ = renderer.render(.now)
        let returned = outer && !inner && callbacks == ["inner"]
        _ = renderer.handle(.escape)
        _ = renderer.render(.now)
        renderer.unmount()

        // -- Assert --
        #expect(returned)
        #expect(!outer && callbacks == ["inner", "outer"])
    }

    private struct Reentrant: View {
        @State private var presented = true
        let capture: @MainActor (DismissAction) -> Void
        let callback: @MainActor () -> Bool
        var body: some View {
            Text("Base").sheet(
                isPresented: $presented,
                onDismiss: {
                    if callback() { presented = true }
                },
                content: { dismiss in
                    capture(dismiss)
                    return Text("Modal")
                })
        }
    }

    @Test("Reentrant lifecycle writes start a new lifetime without duplicating the prior hook")
    func reentrant() {
        // -- Arrange --
        var current: DismissAction?
        var callbacks = 0
        let renderer = ViewRenderer.make(
            Reentrant(
                capture: { current = $0 },
                callback: {
                    callbacks += 1
                    return callbacks == 1
                }))
        _ = renderer.render(.now)
        let old = current

        // -- Act --
        old?()
        _ = renderer.render(.now)
        _ = renderer.render(.now)
        old?()
        let reopened = renderer.render(.now)
        let once = callbacks == 1 && reopened.grid?.snapshotText == "Modal"
        current?()
        _ = renderer.render(.now)

        // -- Assert --
        #expect(once && callbacks == 2)
    }

    @Test("External binding dismissal uses the current callback and runs once")
    func externalDismissal() {
        // -- Arrange --
        var presented = true
        var callbacks: [Int] = []
        func content(_ version: Int) -> some View {
            Text("Base").sheet(
                isPresented: Binding(get: { presented }, set: { presented = $0 }),
                onDismiss: { callbacks.append(version) }, content: { Text("Modal") })
        }
        let renderer = ViewRenderer.make(content(1))
        _ = renderer.render(.now)
        renderer.update(content(2), at: .now)
        _ = renderer.render(.now)

        // -- Act --
        presented = false
        renderer.update(content(3), at: .now)
        _ = renderer.render(.now)
        renderer.unmount()

        // -- Assert --
        #expect(callbacks == [3])
    }
}

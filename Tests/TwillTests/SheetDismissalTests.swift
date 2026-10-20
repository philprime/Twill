import Testing

@testable import Twill

@Suite("Sheet dismissal lifecycle")
@MainActor
struct SheetDismissalTests {
    @Test("Scoped dismissal clears the binding and delivers one lifecycle hook")
    func scopedDismissal() {
        // -- Arrange --
        var presented = true
        var callbacks = 0
        let renderer = ViewRenderer.make(
            Text("Base").sheet(
                isPresented: Binding(get: { presented }, set: { presented = $0 }), onDismiss: { callbacks += 1 },
                content: { dismiss in
                    Button("Close") {
                        dismiss()
                        dismiss()
                    }
                }))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.render(.now)
        renderer.unmount()

        // -- Assert --
        #expect(!presented && callbacks == 1)
    }

    @Test("Unhandled Escape dismisses ordinary sheets while manual policy retains them")
    func escapePolicy() {
        // -- Arrange --
        for policy in [SheetDismissalPolicy.escape, .manual] {
            var presented = true
            var callbacks = 0
            let renderer = ViewRenderer.make(
                Text("Base").sheet(
                    isPresented: Binding(get: { presented }, set: { presented = $0 }), dismissalPolicy: policy,
                    onDismiss: { callbacks += 1 }, content: { Text("Modal") }))
            _ = renderer.render(.now)

            // -- Act --
            let consumed = renderer.handle(.escape)
            _ = renderer.render(.now)

            // -- Assert --
            #expect(consumed)
            #expect(presented == (policy == .manual))
            #expect(callbacks == (policy == .escape ? 1 : 0))
            renderer.unmount()
        }
    }

    @Test("Content handlers retain Escape refusal before automatic dismissal")
    func handledEscape() {
        // -- Arrange --
        var presented = true
        var callbacks = 0
        let renderer = ViewRenderer.make(
            Text("Base").sheet(
                isPresented: Binding(get: { presented }, set: { presented = $0 }), onDismiss: { callbacks += 1 },
                content: {
                    Text("Modal").onKeyPress { $0 == .escape ? .handled : .ignored }
                }))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.escape)
        _ = renderer.render(.now)

        // -- Assert --
        #expect(presented && callbacks == 0)
        renderer.unmount()
    }

    @Test("A stale scoped action cannot dismiss a later presentation lifetime")
    func staleAction() {
        // -- Arrange --
        var presented = true
        var current: DismissAction?
        var callbacks = 0
        func content() -> some View {
            Text("Base").sheet(
                isPresented: Binding(get: { presented }, set: { presented = $0 }),
                onDismiss: { callbacks += 1 },
                content: { dismiss in
                    current = dismiss
                    return Text("Modal")
                })
        }
        let renderer = ViewRenderer.make(content())
        _ = renderer.render(.now)
        let old = current
        old?()
        _ = renderer.render(.now)
        presented = true
        renderer.update(content(), at: .now)
        _ = renderer.render(.now)

        // -- Act --
        old?()
        _ = renderer.render(.now)

        // -- Assert --
        #expect(presented && callbacks == 1)
        current?()
        _ = renderer.render(.now)
        #expect(!presented && callbacks == 2)
    }

    @Test("Removing a presented parent ends the lifecycle once")
    func parentRemoval() {
        // -- Arrange --
        var callbacks = 0
        @ViewBuilder func content(_ show: Bool) -> some View {
            if show {
                Text("Base").sheet(
                    isPresented: .constant(true), onDismiss: { callbacks += 1 }, content: { Text("Modal") })
            } else {
                Text("Removed")
            }
        }
        let renderer = ViewRenderer.make(content(true))
        _ = renderer.render(.now)

        // -- Act --
        renderer.update(content(false), at: .now)
        _ = renderer.render(.now)
        renderer.unmount()

        // -- Assert --
        #expect(callbacks == 1)
    }
}

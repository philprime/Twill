import Testing

@testable import Twill

@Suite("Focus transition decisions")
@MainActor
struct FocusCoordinatorTests {
    @Test("Resolving an explicit request has no effects until its transition is applied")
    func deferredTransition() throws {
        // -- Arrange --
        var firstFocused = false
        var secondFocused = false
        var writes: [String] = []
        let renderer = ViewRenderer.make(
            HStack {
                Text("First").focusable().focused(
                    FocusState<Bool>.Binding(
                        get: { firstFocused },
                        set: {
                            firstFocused = $0
                            writes.append("first")
                        }))
                Text("Second").focusable().focused(
                    FocusState<Bool>.Binding(
                        get: { secondFocused },
                        set: {
                            secondFocused = $0
                            writes.append("second")
                        }))
            })
        _ = renderer.render(.now)
        let targets = renderer.focusableNodes()
        let first = try #require(targets.first)
        let second = try #require(targets.last)
        writes = []
        secondFocused = true

        // -- Act --
        let request = renderer.focusRequest()
        let transition = FocusCoordinator().resolve(request)
        let unchangedBeforeApplication = renderer.focusState.presentedFocus === first && writes.isEmpty
        renderer.applyFocusTransition(transition)
        let writesAfterApplication = writes
        renderer.applyFocusTransition(transition)

        // -- Assert --
        #expect(unchangedBeforeApplication)
        #expect(transition.target === second)
        #expect(renderer.focusState.presentedFocus === second)
        #expect(!firstFocused && secondFocused)
        // The requested binding is already true. Only the previous target needs a write.
        #expect(writesAfterApplication == ["first"])
        #expect(writes == writesAfterApplication)
    }

    @Test("A cleared binding resolves to no target without changing presentation before application")
    func deferredClear() throws {
        // -- Arrange --
        var focused = true
        let renderer = ViewRenderer.make(
            Text("Control").focusable().focused(
                FocusState<Bool>.Binding(get: { focused }, set: { focused = $0 })))
        _ = renderer.render(.now)
        let original = try #require(renderer.focusState.presentedFocus)
        focused = false

        // -- Act --
        let transition = FocusCoordinator().resolve(renderer.focusRequest())
        let presentedBeforeApplication = renderer.focusState.presentedFocus
        renderer.applyFocusTransition(transition)

        // -- Assert --
        #expect(transition.target == nil)
        #expect(presentedBeforeApplication === original)
        #expect(renderer.focusState.presentedFocus == nil)
        #expect(!focused)
    }
}

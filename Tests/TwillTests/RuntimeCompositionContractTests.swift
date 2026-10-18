import Foundation
import Testing

@testable import Twill

@Suite("Runtime composition contracts")
@MainActor
struct RuntimeCompositionContractTests {
    @Test("Hidden timeline ticks cannot activate a tab's focus, handlers, or sheet")
    func hiddenTimelineInteraction() throws {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var selection = 0
        var hiddenFocus = true
        var dates: [Date] = []
        var activeKeys: [KeyEvent] = []
        var hiddenKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            TabView(selection: Binding(get: { selection }, set: { selection = $0 })) {
                Tab("Active", value: 0) {
                    Text("Visible").focusable().onKeyPress { key in
                        activeKeys.append(key)
                        return .handled
                    }
                }
                Tab("Hidden", value: 1) {
                    TimelineView(.periodic(from: start, by: 1)) { context in
                        dates.append(context.date)
                        return Text("Hidden content").focusable()
                            .sheet(isPresented: Binding(get: { true }, set: { _ in })) {
                                Text("Hidden modal").focusable().onKeyPress { key in
                                    hiddenKeys.append(key)
                                    return .handled
                                }
                            }
                            .focused(FocusState<Bool>.Binding(get: { hiddenFocus }, set: { hiddenFocus = $0 }))
                            .onKeyPress { key in
                                hiddenKeys.append(key)
                                return .handled
                            }
                    }
                }
            })
        _ = renderer.render(start)
        _ = renderer.handle(.arrowDown)
        let initial = renderer.render(start)

        // -- Act --
        let firstHandled = renderer.handle(.x)
        hiddenFocus = true
        let ticked = renderer.render(start.addingTimeInterval(1))
        let secondHandled = renderer.handle(.x)

        // -- Assert --
        #expect(firstHandled && secondHandled)
        #expect(dates == [start, start.addingTimeInterval(1)])
        #expect(ticked.nextUpdate == start.addingTimeInterval(2))
        #expect(ticked.grid == initial.grid)
        let grid = try #require(ticked.grid)
        #expect(grid.snapshotText.contains("Visible"))
        #expect(grid.isFocused(column: 0, row: 1))
        #expect(activeKeys == [.x, .x])
        #expect(hiddenKeys.isEmpty)
        #expect(selection == 0)
    }

    @Test("Nested modal dismissal falls back when its saved enclosing target was removed")
    func removedNestedModalTarget() throws {
        // -- Arrange --
        var activated: [String] = []
        var leaked: [KeyEvent] = []
        var innerKeys: [KeyEvent] = []
        let renderer = ViewRenderer.make(
            RemovingModalTarget(
                activate: { activated.append($0) }, leak: { leaked.append($0) },
                innerKey: { innerKeys.append($0) }))
        _ = renderer.render(.now)
        _ = renderer.handle(.o)
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        let savedFocus = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.n)
        _ = renderer.render(.now)

        // -- Act --
        let trapped = renderer.handle(.x)
        _ = renderer.render(.now)
        _ = renderer.handle(.escape)
        _ = renderer.render(.now)
        let outerHandled = renderer.handle(.enter)
        _ = renderer.handle(.escape)
        _ = renderer.render(.now)
        let baseHandled = renderer.handle(.enter)

        // -- Assert --
        #expect(trapped)
        #expect(outerHandled && baseHandled)
        #expect(savedFocus.isFocused(column: 0, row: 1))
        #expect(innerKeys == [.x, .escape])
        #expect(leaked.isEmpty)
        #expect(activated == ["first", "base"])
    }

    private struct RemovingModalTarget: View {
        @State private var outerPresented = false
        @State private var innerPresented = false
        @State private var hasSecond = true
        let activate: (String) -> Void
        let leak: (KeyEvent) -> Void
        let innerKey: (KeyEvent) -> Void

        var body: some View {
            Button("Base") { activate("base") }
                .onKeyPress { key in
                    if key == .o {
                        outerPresented = true
                        return .handled
                    }
                    if key == .x { leak(key) }
                    return .ignored
                }
                .sheet(isPresented: $outerPresented) {
                    VStack {
                        Button("First") { activate("first") }
                        if hasSecond { Button("Second") { activate("second") } }
                    }
                    .onKeyPress { key in
                        if key == .n {
                            innerPresented = true
                            return .handled
                        }
                        if key == .escape {
                            outerPresented = false
                            return .handled
                        }
                        if key == .x { leak(key) }
                        return .ignored
                    }
                    .sheet(isPresented: $innerPresented) {
                        Text("Inner").focusable().onKeyPress { key in
                            innerKey(key)
                            if key == .x { hasSecond = false }
                            if key == .escape {
                                innerPresented = false
                                return .handled
                            }
                            return .ignored
                        }
                    }
                }
        }
    }
}

import Foundation
import Testing

@testable import Twill

@Suite("Automatic control focus lifetimes")
@MainActor
struct KeyboardPaneFocusTests {
    @Test("Programmatic focus can activate another control without wrappers")
    func programmaticFocus() {
        // -- Arrange --
        var focused = false
        var text = ""
        var activated = false
        let renderer = ViewRenderer.make(
            HStack {
                Button("First") { activated = true }
                TextField("Second", text: Binding(get: { text }, set: { text = $0 }))
                    .focused(FocusState<Bool>.Binding(get: { focused }, set: { focused = $0 }))

            })
        _ = renderer.render(.now)

        // -- Act --
        focused = true
        _ = renderer.render(.now)
        _ = renderer.handle(.x)
        let returned = renderer.handle(.shiftTab)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(text == "x")
        #expect(returned && activated)
        #expect(!focused)
    }

    @Test("Modals trap keys and dismissal restores the underlying control")
    func modalIsolation() {
        // -- Arrange --
        var presented = false
        var activated: [String] = []
        var leaked = 0
        func content() -> some View {
            VStack {
                Button("A1") { activated.append("A1") }
                Button("A2") { activated.append("A2") }
            }

            .onKeyPress { key in
                guard key == .x else { return .ignored }
                leaked += 1
                return .handled
            }
            .sheet(isPresented: Binding(get: { presented }, set: { presented = $0 })) {
                HStack {
                    Button("Modal1") { activated.append("Modal1") }
                    Button("Modal2") { activated.append("Modal2") }
                }
            }
        }
        let renderer = ViewRenderer.make(content())
        _ = renderer.render(.now)
        _ = renderer.handle(.arrowDown)
        presented = true
        renderer.update(content(), at: .now)
        _ = renderer.render(.now)

        // -- Act --
        let switched = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.x)
        presented = false
        renderer.update(content(), at: .now)
        _ = renderer.render(.now)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(switched)
        #expect(activated == ["Modal2", "A2"])
        #expect(leaked == 0)
    }

    @Test("Parent updates preserve pane focus and removal preserves sibling deadlines")
    func parentUpdatesAndRemoval() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var activated: [String] = []
        var siblingDates: [Date] = []
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { context in
                HStack {
                    if context.date < start.addingTimeInterval(2) {
                        VStack {
                            Button("A1") { activated.append("A1") }
                            Button("A2") { activated.append("A2") }
                        }
                    }
                    Group {
                        VStack {
                            TimelineView(.periodic(from: start, by: 10)) { child in
                                siblingDates.append(child.date)
                                return Text("Static")
                            }
                            Button("B") { activated.append("B") }
                        }
                    }
                }
            })
        _ = renderer.render(start)
        _ = renderer.handle(.arrowDown)

        // -- Act --
        _ = renderer.render(start.addingTimeInterval(1))
        _ = renderer.handle(.enter)
        let removed = renderer.render(start.addingTimeInterval(2))
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(activated == ["A2", "B"])
        #expect(siblingDates == [start, start, start])
        #expect(removed.nextUpdate == start.addingTimeInterval(3))
    }
}

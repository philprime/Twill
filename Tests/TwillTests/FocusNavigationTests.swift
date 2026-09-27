import Foundation
import Testing

@testable import Twill

@Suite("Arrow-key focus navigation")
@MainActor
struct FocusNavigationTests {
    @Test("The first focusable control is visibly focused on initial presentation")
    func focusIndicator() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 1) {
                Text("One").focusable()
                Text("Two").focusable()
            })

        // -- Act --
        let frame = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(InlineFrameEncoder.encode(frame, previous: nil) == "\r\u{1B}[2K\u{1B}[7mOne\u{1B}[27m Two")
    }

    @Test("A handled arrow stays with the focused control")
    func handledArrow() {
        // -- Arrange --
        var activated: [String] = []
        let root = HStack {
            Text("First").focusable().onKeyPress { key in
                switch key {
                case .arrowDown: return .handled
                case .enter:
                    activated.append("First")
                    return .handled
                default: return .ignored
                }
            }
            Text("Second").focusable().onKeyPress { key in
                guard key == .enter else { return .ignored }
                activated.append("Second")
                return .handled
            }
        }
        let renderer = ViewRenderer.make(root)
        _ = renderer.render(.now)

        // -- Act --
        let consumed = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(consumed)
        #expect(activated == ["First"])
    }

    @Test("Removing a focused branch focuses the first remaining control")
    func removedFocus() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var visible = true
        var activated: [String] = []
        let root = TimelineView(.periodic(from: start, by: 1)) { _ in
            VStack {
                if visible {
                    Text("First").focusable().onKeyPress { key in
                        guard key == .enter else { return .ignored }
                        activated.append("First")
                        return .handled
                    }
                }
                Text("Second").focusable().onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    activated.append("Second")
                    return .handled
                }
            }
        }
        let renderer = ViewRenderer.make(root)
        _ = renderer.render(start)

        // -- Act --
        _ = renderer.handle(.enter)
        visible = false
        _ = renderer.render(start.addingTimeInterval(1))
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(activated == ["First", "Second"])
    }

    @Test("A key handler inside the focusable modifier receives the focused key")
    func innerKeyHandler() {
        // -- Arrange --
        var activations = 0
        let root = Text("Action")
            .onKeyPress { key in
                guard key == .enter else { return .ignored }
                activations += 1
                return .handled
            }
            .focusable()
        let renderer = ViewRenderer.make(root)
        _ = renderer.render(.now)

        // -- Act --
        let handled = renderer.handle(.enter)

        // -- Assert --
        #expect(handled)
        #expect(activations == 1)
    }

    @Test("Arrows follow focusable order across rows and columns; Tab leaves focus unchanged")
    func orderedNavigation() {
        // -- Arrange --
        var activated: [String] = []
        let root = VStack {
            HStack(spacing: 4) {
                Text("A").focusable().onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    activated.append("A")
                    return .handled
                }
                Text("B").focusable().onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    activated.append("B")
                    return .handled
                }
            }
            HStack(spacing: 4) {
                Text("C").focusable().onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    activated.append("C")
                    return .handled
                }
                Text("D").focusable().onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    activated.append("D")
                    return .handled
                }
            }
        }
        let renderer = ViewRenderer.make(root)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.tab)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowUp)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(activated == ["A", "B", "B", "C", "B", "A"])
    }

    @Test("Down arrow moves focus between interactive rows, skipping a header")
    func verticalNavigation() {
        // -- Arrange --
        var activated: [String] = []
        let root = VStack {
            Text("Section")
            Text("First")
                .focusable()
                .onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    activated.append("First")
                    return .handled
                }
            Text("Second")
                .focusable()
                .onKeyPress { key in
                    guard key == .enter else { return .ignored }
                    activated.append("Second")
                    return .handled
                }
        }
        let renderer = ViewRenderer.make(root)
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.enter)
        _ = renderer.handle(.arrowDown)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(activated == ["First", "Second"])
    }
}

import Foundation
import Testing

@testable import Twill

@Suite("Mounted tab discovery")
@MainActor
struct TabDiscoveryTests {
    private struct DynamicDestinations: View {
        @State private var showsFirst = true
        let capture: (Binding<Bool>) -> Void

        var body: some View {
            capture($showsFirst)
            return Group {
                if showsFirst {
                    Tab("First", value: 0) { Text("First content") }.padding(1)
                }
                Tab("Second", value: 1) { Text("Second content") }
            }
        }
    }

    private struct DiscoveryRoot: View {
        @State private var nestedSelection = 0
        let capture: (Binding<Bool>) -> Void
        let evaluated: () -> Void

        var body: some View {
            evaluated()
            return Group {
                DynamicDestinations(capture: capture)
                TabView(selection: $nestedSelection) {
                    Tab("Nested", value: 0) { Text("Nested content") }
                }
            }
        }
    }

    @Test("Mounted discovery follows descendant changes without reevaluating parents or escaping nested tab scopes")
    func descendantChanges() throws {
        // -- Arrange --
        var showsFirst: Binding<Bool>?
        var evaluations = 0
        let renderer = ViewRenderer.make(
            DiscoveryRoot(capture: { showsFirst = $0 }, evaluated: { evaluations += 1 }))
        _ = renderer.render(.now)
        let initial = renderer.descendantTabNodes
        let second = try #require(initial.last)
        let mountedEvaluations = evaluations
        let binding = try #require(showsFirst)

        // -- Act --
        binding.wrappedValue = false
        _ = renderer.render(.now)
        let removed = renderer.descendantTabNodes
        binding.wrappedValue = true
        _ = renderer.render(.now)
        let restored = renderer.descendantTabNodes

        // -- Assert --
        #expect(initial.count == 2)
        #expect(removed.count == 1)
        #expect(removed.first === second)
        #expect(restored.count == 2)
        #expect(restored.last === second)
        #expect(evaluations == mountedEvaluations)
    }

    @Test("Scheduled branch replacement refreshes discovery and unmount releases it")
    func timelineAndUnmount() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 1)) { context in
                Group {
                    if context.date == start {
                        Tab("Timed", value: 0) { Text("Visible") }
                    } else {
                        Text("No destinations")
                    }
                }
            })
        _ = renderer.render(start)
        let mountedCount = renderer.descendantTabNodes.count

        // -- Act --
        _ = renderer.render(start.addingTimeInterval(1))
        let updatedCount = renderer.descendantTabNodes.count
        renderer.unmount()

        // -- Assert --
        #expect(mountedCount == 1)
        #expect(updatedCount == 0)
        #expect(renderer.descendantTabNodes.isEmpty)
    }

    @Test("Discovery does not retain removed destinations after unmount")
    func releasesDestinations() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Group { Tab("Only", value: 0) { Text("Content") } })
        _ = renderer.render(.now)
        weak let destination = renderer.descendantTabNodes.first
        let wasMounted = destination != nil

        // -- Act --
        renderer.unmount()

        // -- Assert --
        #expect(wasMounted)
        #expect(destination == nil)
    }
}

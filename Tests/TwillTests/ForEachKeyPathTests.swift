import Foundation
import Testing

@testable import Twill

@Suite("Explicit collection identity")
@MainActor
struct ForEachKeyPathTests {
    private struct Item {
        let key: String
        let label: String
    }

    @Test("A key path identifies non-Identifiable elements across reordering")
    func reordering() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var items = [Item(key: "a", label: "Alpha"), Item(key: "b", label: "Beta")]
        let root = TimelineView(.periodic(from: start, by: 1)) { _ in
            VStack {
                ForEach(items, id: \.key) { item in
                    TimelineView(.periodic(from: start, by: 10)) { context in
                        Text("\(item.label):\(Int(context.date.timeIntervalSince(start)))")
                    }
                }
            }
        }
        let renderer = ViewRenderer.make(root)

        // -- Act --
        let initial = renderer.render(start)
        items.reverse()
        let reordered = renderer.render(start.addingTimeInterval(1))

        // -- Assert --
        #expect(initial.grid?.snapshotText == "Alpha:0\nBeta:0 ")
        #expect(reordered.grid?.snapshotText == "Beta:0 \nAlpha:0")
    }
}

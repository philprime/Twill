import Foundation
import Testing

@testable import Twill

@Suite("Table column layout scheduling")
@MainActor
struct TableColumnLayoutSchedulingTests {
    @Test("Width updates preserve keyed rows and independent timeline phases")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(_ width: Int) -> some View {
            HStack {
                Table([1], id: \.self) {
                    TableColumn("Row") { _ in
                        TimelineView(.periodic(from: start, by: 10)) { context in
                            dates.append(context.date)
                            return Text("Value")
                        }
                    }.width(width)
                }
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content(6))
        _ = renderer.render(start)
        weak var row: ViewRenderer?
        row = renderer.keyedNode(for: 1)

        // -- Act --
        renderer.update(content(8), at: start.addingTimeInterval(1))
        let changed = renderer.render(start.addingTimeInterval(1))
        let retained = row != nil && row === renderer.keyedNode(for: 1)
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(retained)
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start])
        #expect(changed.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
    }
}

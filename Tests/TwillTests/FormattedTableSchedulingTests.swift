import Foundation
import Testing

@testable import Twill

@Suite("Formatted table scheduling")
@MainActor
struct FormattedTableSchedulingTests {
    private struct Row: Identifiable {
        let id = 1
        let value = 2
    }

    @Test("Formatter updates retain independent enclosing timeline phases")
    func independentDeadlines() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        var siblingDates: [Date] = []
        func content(_ suffix: String) -> some View {
            HStack {
                TimelineView(.periodic(from: start, by: 10)) { context in
                    dates.append(context.date)
                    return Table([Row()]) { TableColumn("Value", value: \.value, format: { "\($0) \(suffix)" }) }
                }
                TimelineView(.periodic(from: start, by: 20)) { context in
                    siblingDates.append(context.date)
                    return Text("Sibling")
                }
            }
        }
        let renderer = ViewRenderer.make(content("old"))
        _ = renderer.render(start)

        // -- Act --
        renderer.update(content("new"), at: start.addingTimeInterval(1))
        let changed = renderer.render(start.addingTimeInterval(1))
        let ticked = renderer.render(start.addingTimeInterval(10))

        // -- Assert --
        #expect(dates == [start, start, start.addingTimeInterval(10)])
        #expect(siblingDates == [start, start])
        #expect(changed.nextUpdate == start.addingTimeInterval(10))
        #expect(ticked.nextUpdate == start.addingTimeInterval(20))
    }
}

import Foundation
import Testing

@testable import Twill

@Suite("Timeline rendering")
@MainActor
struct TimelineViewTests {
    @Test("Custom view bodies resolve to text without a timer")
    func staticBody() {
        // -- Arrange --
        let renderer = ViewRenderer.make(Label())

        // -- Act --
        let frame = renderer.render(Date(timeIntervalSinceReferenceDate: 100))

        // -- Assert --
        #expect(frame.text == "Hello")
        #expect(frame.nextUpdate == nil)
    }

    @Test("A custom root keeps its timeline while rendering updated date labels")
    func mountedTimeline() {
        // -- Arrange --
        var bodyEvaluations = 0
        let renderer = ViewRenderer.make(ScheduledLabel { bodyEvaluations += 1 })
        let date = Date(timeIntervalSinceReferenceDate: 100)

        // -- Act --
        let first = renderer.render(date)
        let second = renderer.render(date.addingTimeInterval(1))

        // -- Assert --
        #expect(bodyEvaluations == 1)
        #expect(first.text != second.text)
        #expect(first.nextUpdate != nil)
        #expect(second.nextUpdate != nil)
    }

    @Test("A periodic timeline updates its content and skips missed deadlines")
    func periodicContent() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var dates: [Date] = []
        let view = TimelineView(.periodic(from: start, by: 0.05)) { context -> Text in
            dates.append(context.date)
            return Text("Frame \(dates.count)")
        }
        let renderer = ViewRenderer.make(view)
        let later = start.addingTimeInterval(0.18)

        // -- Act --
        let first = renderer.render(start)
        let delayed = renderer.render(later)

        // -- Assert --
        #expect(first.text == "Frame 1")
        #expect(first.nextUpdate == start.addingTimeInterval(0.05))
        #expect(delayed.text == "Frame 2")
        #expect(delayed.nextUpdate == start.addingTimeInterval(0.20))
        #expect(dates == [start, later])
    }

    @Test("An exact entry advances to the next period despite floating-point rounding")
    func exactEntry() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let schedule = PeriodicTimelineSchedule.periodic(from: start, by: 0.05)

        // -- Act --
        let next = schedule.nextUpdate(after: start.addingTimeInterval(0.05))

        // -- Assert --
        #expect(next == start.addingTimeInterval(0.10))
    }

    @Test("A future schedule renders immediately but waits for its start date")
    func futureStart() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let renderer = ViewRenderer.make(
            TimelineView(.periodic(from: start, by: 0.05)) { _ in Text("Waiting") }
        )

        // -- Act --
        let frame = renderer.render(start.addingTimeInterval(-1))

        // -- Assert --
        #expect(frame.text == "Waiting")
        #expect(frame.nextUpdate == start)
    }
}

private struct Label: View {
    var body: some View { Text("Hello") }
}

private struct ScheduledLabel: View {
    let onBody: () -> Void

    var body: some View {
        onBody()
        return TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 100), by: 0.05)) { context in
            Text(
                context.date.formatted(
                    .dateTime.hour().minute().second().secondFraction(.fractional(3))
                ))
        }
    }
}

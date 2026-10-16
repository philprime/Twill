import Foundation

/// Logical dates only. The host owns the single timer for the tree's earliest deadline.
struct MountedSchedule {
    private struct Timeline {
        let schedule: PeriodicTimelineSchedule
        let date: Date
        let deadline: Date
    }

    private var timeline: Timeline?
    private(set) var canvasDate: Date?
    private(set) var nextUpdate: Date?

    func isDue(at date: Date) -> Bool {
        timeline.map { date >= $0.deadline } ?? false
    }

    mutating func advance(_ schedule: PeriodicTimelineSchedule, at date: Date) -> Date {
        // An unchanged parent may supply fresh view values before this deadline.
        // Reuse the last context date rather than advancing or restarting the child.
        if let timeline, timeline.schedule == schedule, date < timeline.deadline {
            return timeline.date
        }
        timeline = Timeline(schedule: schedule, date: date, deadline: schedule.nextUpdate(after: date))
        return date
    }

    mutating func updateCanvas(interval: TimeInterval?, at date: Date) {
        guard let interval else {
            timeline = nil
            canvasDate = date
            return
        }
        let start = timeline?.schedule.interval == interval ? timeline!.schedule.start : date
        canvasDate = advance(.periodic(from: start, by: interval), at: date)
    }

    mutating func advanceCanvas(interval: TimeInterval, at date: Date) {
        // Only a due canvas reaches this path, so it already owns a timeline.
        let start = timeline!.schedule.start
        canvasDate = advance(.periodic(from: start, by: interval), at: date)
    }

    mutating func collectDeadlines(_ deadlines: some Sequence<Date?>) {
        nextUpdate = timeline?.deadline
        for deadline in deadlines {
            if let deadline { nextUpdate = min(nextUpdate ?? deadline, deadline) }
        }
    }
}

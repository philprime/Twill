import Foundation

/// A wall-clock schedule anchored to its start, rather than to completion of each render.
public struct PeriodicTimelineSchedule: Sendable, Equatable {
    private let start: Date
    private let interval: TimeInterval

    public static func periodic(from start: Date, by interval: TimeInterval) -> Self {
        precondition(start.timeIntervalSinceReferenceDate.isFinite, "Timeline start must be finite")
        precondition(interval.isFinite && interval > 0, "Timeline interval must be positive and finite")
        return Self(start: start, interval: interval)
    }

    func nextUpdate(after date: Date) -> Date {
        guard date >= start else { return start }
        // Skip missed entries instead of queuing catch-up renders after a slow frame.
        let elapsedIntervals = floor(date.timeIntervalSince(start) / interval)
        var next = start.addingTimeInterval((elapsedIntervals + 1) * interval)
        // Division can round an exact entry down into the preceding period.
        if next <= date { next = start.addingTimeInterval((elapsedIntervals + 2) * interval) }
        // Sub-resolution intervals must still advance to a representable future date.
        return max(next, Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.nextUp))
    }
}

import Foundation

/// Re-evaluates time-dependent content using the application's timer scheduler.
/// Equal schedules retain their mounted timing across parent updates. Changing the
/// start date or interval reconfigures that timing; a parent update alone does not.
public struct TimelineView<Content: View>: View {
    public typealias Body = Never

    // Builders must know the context type before they can infer the content type.
    public typealias Context = TimelineViewContext

    private let schedule: PeriodicTimelineSchedule
    private let content: @MainActor (Context) -> Content

    public init(
        _ schedule: PeriodicTimelineSchedule,
        content: @escaping @MainActor (Context) -> Content
    ) {
        self.schedule = schedule
        self.content = content
    }
}

extension TimelineView: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .timeline(schedule) { date in content(Context(date: date)) }
    }
}

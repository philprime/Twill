import Foundation

/// Primitive descriptions are internal; application views only expose their body.
@MainActor
protocol PrimitiveView {
    func makeDescription() -> ViewDescription
}

@MainActor
enum ViewDescription {
    case text(String?)
    case body(any View)
    case group(children: [any View], separator: String?)
    case conditional(first: Bool, content: any View)
    case timeline(PeriodicTimelineSchedule, @MainActor (Date) -> any View)
}

import Foundation

/// The time of a timeline evaluation, independent of its content's concrete type.
public struct TimelineViewContext: Sendable {
    /// The logical date used to evaluate this timeline presentation.
    public let date: Date
}

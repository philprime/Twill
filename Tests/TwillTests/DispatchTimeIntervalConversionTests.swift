import Dispatch
import Testing

@testable import Twill

@Suite("Dispatch time interval conversion")
struct DispatchTimeIntervalConversionTests {
    @Test(
        "Positive intervals convert to nanoseconds",
        arguments: [
            (DispatchTimeInterval.seconds(2), UInt64(2_000_000_000)),
            (.milliseconds(2), 2_000_000),
            (.microseconds(2), 2_000),
            (.nanoseconds(2), 2),
        ]
    )
    func positiveIntervals(value: DispatchTimeInterval, expected: UInt64) {
        // -- Arrange --
        let interval = value

        // -- Act --
        let nanoseconds = interval.nanoseconds

        // -- Assert --
        #expect(nanoseconds == expected)
    }

    @Test(
        "Zero and negative intervals have no nanosecond conversion",
        arguments: [
            DispatchTimeInterval.seconds(0), .seconds(-1), .seconds(Int.min),
            .milliseconds(0), .milliseconds(-1), .milliseconds(Int.min),
            .microseconds(0), .microseconds(-1), .microseconds(Int.min),
            .nanoseconds(0), .nanoseconds(-1), .nanoseconds(Int.min),
        ]
    )
    func nonpositiveIntervals(value: DispatchTimeInterval) {
        // -- Arrange --
        let interval = value

        // -- Act --
        let nanoseconds = interval.nanoseconds

        // -- Assert --
        #expect(nanoseconds == nil)
    }

    @Test("Never has no nanosecond conversion")
    func neverInterval() {
        // -- Arrange --
        let interval = DispatchTimeInterval.never

        // -- Act --
        let nanoseconds = interval.nanoseconds

        // -- Assert --
        #expect(nanoseconds == nil)
    }
}

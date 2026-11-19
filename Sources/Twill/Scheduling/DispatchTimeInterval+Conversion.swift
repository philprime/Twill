import Dispatch

extension DispatchTimeInterval {
    var nanoseconds: UInt64? {
        switch self {
        case .seconds(let value):
            value > 0 ? UInt64(value) * 1_000_000_000 : nil
        case .milliseconds(let value):
            value > 0 ? UInt64(value) * 1_000_000 : nil
        case .microseconds(let value):
            value > 0 ? UInt64(value) * 1_000 : nil
        case .nanoseconds(let value):
            value > 0 ? UInt64(value) : nil
        case .never:
            nil
        @unknown default:
            nil
        }
    }
}

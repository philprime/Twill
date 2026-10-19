/// A service contract used by the real-package discovery test.
public protocol Service {}
/// A service implementation with a nested type.
public struct Worker: Service {
    /// The worker's execution state.
    public enum Status {
        /// The worker can accept work.
        case ready
    }
    /// Creates a worker.
    public init() {}
}

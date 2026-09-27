#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

/// A borrowed POSIX descriptor. Wrapping it does not transfer ownership or close it.
public enum FileDescriptor: Sendable, Equatable {
    case standardInput
    case standardOutput
    case standardError
    case custom(Int32)

    /// POSIX uses signed descriptors. Keep conversion at the system-call boundary.
    public var rawValue: Int32 {
        switch self {
        case .standardInput: STDIN_FILENO
        case .standardOutput: STDOUT_FILENO
        case .standardError: STDERR_FILENO
        case .custom(let descriptor): descriptor
        }
    }
}

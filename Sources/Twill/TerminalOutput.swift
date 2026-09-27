import Foundation

#if TESTING
    @MainActor
    public protocol TerminalOutput: AnyObject {
        func write(_ text: String) throws
    }

    extension DefaultTerminalOutput: TerminalOutput {}
#else
    public typealias TerminalOutput = DefaultTerminalOutput
#endif

/// Writes complete presentation buffers without stdio's newline buffering.
@MainActor
public final class DefaultTerminalOutput {
    private let handle: FileHandle

    /// Borrows the descriptor. Its owner must keep it open until the application stops.
    public init(fileDescriptor: FileDescriptor = .standardOutput) {
        handle = FileHandle(fileDescriptor: fileDescriptor.rawValue, closeOnDealloc: false)
    }

    public func write(_ text: String) throws {
        try handle.write(contentsOf: Data(text.utf8))
    }
}

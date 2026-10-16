import Foundation

#if TESTING
    /// A replaceable destination for complete terminal presentation buffers.
    @MainActor
    public protocol TerminalOutput: AnyObject {
        /// Writes the UTF-8 text, throwing if the output operation fails.
        func write(_ text: String) throws
    }

    extension DefaultTerminalOutput: TerminalOutput {}
#else
    /// The concrete destination used for terminal presentation buffers.
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

    /// Writes the complete text as UTF-8 bytes to the borrowed descriptor.
    public func write(_ text: String) throws {
        try handle.write(contentsOf: Data(text.utf8))
    }
}

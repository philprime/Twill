#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

#if DEBUG
    /// Owns temporary input-mode changes, not the input reader or the terminal screen.
    @MainActor
    public protocol TerminalSession: AnyObject {
        var fileDescriptor: FileDescriptor { get }
        func start() throws
        func restore()
    }

    extension DefaultTerminalSession: TerminalSession {}
#else
    public typealias TerminalSession = DefaultTerminalSession
#endif

/// Temporarily borrows the terminal's input configuration from the host shell.
///
/// A shell normally uses canonical input and echo: bytes are held until Enter and
/// typed characters are printed automatically. A keyboard-driven application needs
/// immediate, unechoed input instead. This session saves termios before enabling
/// that mode, then restores it so the shell remains usable after the application exits.
/// Input translations and software flow control are disabled so UTF-8 and control keys
/// reach the parser unchanged. Read timeouts belong to the event-driven runtime instead
/// of the terminal driver. Output processing is preserved for the current print-based UI.
///
/// Application must stop its input readers before calling restore(). This object
/// neither closes the descriptor nor enters an alternate screen or writes output.
/// Restoration covers orderly shutdown, not process crashes or fatal signals.
@MainActor
public final class DefaultTerminalSession {
    private static let softwareFlowControl = tcflag_t(IXON | IXOFF | IXANY)
    private static let minimumReadBytes: cc_t = 1
    private static let readTimeoutDeciseconds: cc_t = 0

    public let fileDescriptor: FileDescriptor
    private var original: termios?

    public init(fileDescriptor: FileDescriptor = .standardInput) {
        self.fileDescriptor = fileDescriptor
    }

    public func start() throws {
        var saved = termios()
        guard tcgetattr(fileDescriptor.rawValue, &saved) == 0 else {
            throw TerminalError.readAttributes(errno: errno)
        }
        var mode = saved
        // cfmakeraw disables canonical editing, echo (including ECHONL), signals and
        // extended shortcuts. It also disables CR/LF translation and bit stripping,
        // preserving Enter, control keys and UTF-8 bytes for the application parser.
        // With ISIG off, Ctrl-C reaches Application and can unwind through cleanup.
        cfmakeraw(&mode)

        // cfmakeraw leaves IXANY set on Darwin, and IXOFF as well on Linux. Neither
        // inherited flow control nor Ctrl-S/Ctrl-Q should pause or consume TUI traffic.
        mode.c_iflag &= ~Self.softwareFlowControl

        // The reader uses O_NONBLOCK and Dispatch readiness, not termios timeouts.
        // VMIN=1 avoids treating an idle zero-byte read as EOF. VTIME=0 leaves Escape
        // disambiguation to our run-loop timer rather than a second timeout mechanism.
        withUnsafeMutableBytes(of: &mode.c_cc) { characters in
            characters[Int(VMIN)] = Self.minimumReadBytes
            characters[Int(VTIME)] = Self.readTimeoutDeciseconds
        }

        // Preserve the host's newline handling while examples use print(). A future
        // byte-exact ANSI presenter should leave OPOST disabled and emit CR/LF itself.
        mode.c_oflag = saved.c_oflag
        guard tcsetattr(fileDescriptor.rawValue, TCSANOW, &mode) == 0 else {
            throw TerminalError.writeAttributes(errno: errno)
        }
        original = saved
    }

    public func restore() {
        guard var original else { return }
        _ = tcsetattr(fileDescriptor.rawValue, TCSANOW, &original)
        self.original = nil
    }
}

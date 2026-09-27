#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

#if TESTING
    /// Owns borrowed input modes and presentation modes, but not input readers or rendering.
    @MainActor
    public protocol TerminalSession: AnyObject {
        var fileDescriptor: FileDescriptor { get }
        var output: TerminalOutput { get }
        func start() throws
        func beginPresentation(mode: Application.Options.UIOptions.Mode) throws
        func restore()
    }

    extension DefaultTerminalSession: TerminalSession {}
#else
    public typealias TerminalSession = DefaultTerminalSession
#endif

/// Temporarily borrows terminal input modes and native cursor visibility from the host shell.
///
/// A shell normally uses canonical input and echo: bytes are held until Enter and
/// typed characters are printed automatically. A keyboard-driven application needs
/// immediate, unechoed input instead. This session saves termios before enabling
/// that mode, then restores it so the shell remains usable after the application exits.
/// Input translations and software flow control are disabled so UTF-8 and control keys
/// reach the parser unchanged. Read timeouts belong to the event-driven runtime instead
/// of the terminal driver. Output processing is preserved for the current print-based UI.
///
/// Application joins input and resize consumers before calling restore(). Cursor
/// control uses the same injected output as frame presentation. This object neither
/// closes borrowed descriptors. Fullscreen presentation borrows the alternate screen.
/// Restoration covers orderly shutdown, not process crashes or fatal signals.
@MainActor
public final class DefaultTerminalSession {
    private static let softwareFlowControl = tcflag_t(IXON | IXOFF | IXANY)
    private static let minimumReadBytes: cc_t = 1
    private static let readTimeoutDeciseconds: cc_t = 0
    private static let enterAlternateScreen = "\u{1B}[?1049h\u{1B}[2J\u{1B}[H"
    private static let leaveAlternateScreen = "\u{1B}[?1049l"
    private static let hideCursor = "\u{1B}[?25l"
    private static let showCursor = "\u{1B}[?25h"

    public let fileDescriptor: FileDescriptor
    public let output: TerminalOutput
    private var original: termios?
    private var needsCursorRestore = false
    private var needsScreenRestore = false

    public init(fileDescriptor: FileDescriptor = .standardInput, output: TerminalOutput = DefaultTerminalOutput()) {
        self.fileDescriptor = fileDescriptor
        self.output = output
    }

    /// Acquires presentation modes lazily so event-only applications leave the cursor alone.
    public func beginPresentation(mode: Application.Options.UIOptions.Mode = .inline) throws {
        guard !needsCursorRestore else { return }
        // A write can fail after partially reaching the terminal. Claim cleanup first.
        if mode == .fullscreen {
            needsScreenRestore = true
            try output.write(Self.enterAlternateScreen)
        }
        needsCursorRestore = true
        try output.write(Self.hideCursor)
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
        if needsScreenRestore {
            try? output.write(Self.leaveAlternateScreen)
            needsScreenRestore = false
        }
        if needsCursorRestore {
            // Output restoration is best-effort and must not skip termios restoration.
            try? output.write(Self.showCursor)
            needsCursorRestore = false
        }
        guard var original else { return }
        _ = tcsetattr(fileDescriptor.rawValue, TCSANOW, &original)
        self.original = nil
    }
}

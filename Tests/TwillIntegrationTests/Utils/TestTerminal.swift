import Foundation
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

struct TerminalSnapshot: Equatable {
    let input: tcflag_t
    let output: tcflag_t
    let control: tcflag_t
    let local: tcflag_t
    let characters: [UInt8]
    let inputSpeed: speed_t
    let outputSpeed: speed_t
    let descriptorFlags: Int32
}

/// Keeps both ends open so tests can inspect the terminal after the application exits.
final class TestTerminal {
    private let host: FileHandle
    private let application: FileHandle

    var fileDescriptor: Int32 { application.fileDescriptor }

    init() throws {
        var hostDescriptor: Int32 = -1
        var applicationDescriptor: Int32 = -1
        guard openpty(&hostDescriptor, &applicationDescriptor, nil, nil, nil) == 0 else {
            throw TestApplicationError.systemCall(operation: "openpty", code: errno)
        }
        host = FileHandle(fileDescriptor: hostDescriptor, closeOnDealloc: true)
        application = FileHandle(fileDescriptor: applicationDescriptor, closeOnDealloc: true)
    }

    @MainActor
    func makeApplication(runLoop: Twill.RunLoop = DefaultRunLoop()) -> Application {
        Application(runLoop: runLoop, terminalSession: DefaultTerminalSession(fileDescriptor: .custom(fileDescriptor)))
    }

    func send(_ bytes: [UInt8]) throws {
        try host.write(contentsOf: Data(bytes))
    }

    func configure(_ update: (inout termios) -> Void) throws {
        var state = termios()
        guard tcgetattr(fileDescriptor, &state) == 0 else {
            throw TestApplicationError.systemCall(operation: "tcgetattr", code: errno)
        }
        update(&state)
        guard tcsetattr(fileDescriptor, TCSANOW, &state) == 0 else {
            throw TestApplicationError.systemCall(operation: "tcsetattr", code: errno)
        }
    }

    func snapshot() throws -> TerminalSnapshot {
        var state = termios()
        guard tcgetattr(fileDescriptor, &state) == 0 else {
            throw TestApplicationError.systemCall(operation: "tcgetattr", code: errno)
        }
        // Darwin sets PENDIN when canonical mode is restored, even with no pending
        // input. It is kernel state, not a terminal setting that the session changed.
        #if canImport(Darwin)
            state.c_lflag &= ~tcflag_t(PENDIN)
        #endif
        return TerminalSnapshot(
            input: state.c_iflag, output: state.c_oflag,
            control: state.c_cflag, local: state.c_lflag,
            characters: withUnsafeBytes(of: state.c_cc) { Array($0) },
            inputSpeed: cfgetispeed(&state), outputSpeed: cfgetospeed(&state),
            descriptorFlags: fcntl(fileDescriptor, F_GETFL)
        )
    }
}

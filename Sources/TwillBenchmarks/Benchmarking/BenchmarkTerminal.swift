import Foundation

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

/// Owns only benchmark resources. Application borrows the slave and restores its modes.
final class BenchmarkTerminal {
    let host: FileHandle
    let terminal: FileHandle
    let sink: FileHandle

    init() throws {
        var hostDescriptor: Int32 = -1
        var applicationDescriptor: Int32 = -1
        var size = winsize(ws_row: 40, ws_col: 120, ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&hostDescriptor, &applicationDescriptor, nil, nil, &size) == 0 else {
            throw BenchmarkError.systemCall(errno)
        }
        host = FileHandle(fileDescriptor: hostDescriptor, closeOnDealloc: true)
        terminal = FileHandle(fileDescriptor: applicationDescriptor, closeOnDealloc: true)
        sink = try FileHandle(forWritingTo: URL(fileURLWithPath: "/dev/null"))
        let flags = fcntl(hostDescriptor, F_GETFL)
        // An overloaded PTY must fail the run rather than block the producer beyond its timeout.
        guard flags >= 0, fcntl(hostDescriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
            throw BenchmarkError.systemCall(errno)
        }
    }

    deinit {
        try? host.close()
        try? terminal.close()
        try? sink.close()
    }
}

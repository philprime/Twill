import Dispatch
import Foundation

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

enum TestApplicationError: Error {
    case missingExecutable
    case systemCall(operation: String, code: Int32)
    case timedOut(output: Data)
    case endOfOutput(output: Data)
    case invalidUTF8
}

/// Launches a real executable attached to a terminal, like an app UI-test driver.
final class TestApplication {
    private let process = Process()
    private let terminal: FileHandle
    private let applicationTerminal: FileHandle
    private let terminated = DispatchSemaphore(value: 0)
    private var output = Data()

    var isRunning: Bool { process.isRunning }

    init(
        executablePath: String? = ProcessInfo.processInfo.environment["TWILL_CLOCK_EXECUTABLE"],
        arguments: [String] = [],
        rows: UInt16 = 24,
        columns: UInt16 = 80
    ) throws {
        guard let executablePath else { throw TestApplicationError.missingExecutable }
        var hostDescriptor: Int32 = -1
        var applicationDescriptor: Int32 = -1
        var size = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&hostDescriptor, &applicationDescriptor, nil, nil, &size) == 0 else {
            throw TestApplicationError.systemCall(operation: "openpty", code: errno)
        }
        terminal = FileHandle(fileDescriptor: hostDescriptor, closeOnDealloc: true)
        applicationTerminal = FileHandle(fileDescriptor: applicationDescriptor, closeOnDealloc: true)
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardInput = applicationTerminal
        process.standardOutput = applicationTerminal
        process.standardError = applicationTerminal
        process.terminationHandler = { [terminated] _ in terminated.signal() }
    }

    deinit {
        terminate()
    }

    func launch() throws {
        try process.run()
        try applicationTerminal.close()
    }

    func terminate(timeout: TimeInterval = 2) {
        guard process.isRunning else { return }
        process.terminate()
        // A broken application must not leave a test runner waiting forever.
        if terminated.wait(timeout: .now() + timeout) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
    }

    func waitForLine(timeout: TimeInterval = 5) throws -> String {
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeout * 1_000_000_000)
        while true {
            if let newline = output.firstIndex(of: 10) {
                guard var line = String(data: output[..<newline], encoding: .utf8) else {
                    throw TestApplicationError.invalidUTF8
                }
                output.removeSubrange(...newline)
                if line.hasSuffix("\r") { line.removeLast() }
                return line
            }
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else {
                throw TestApplicationError.timedOut(output: output)
            }
            var descriptor = pollfd(fd: terminal.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let milliseconds = Int32(clamping: max(1, (deadline - now) / 1_000_000))
            let ready = poll(&descriptor, 1, milliseconds)
            if ready < 0 {
                if errno == EINTR { continue }
                throw TestApplicationError.systemCall(operation: "poll", code: errno)
            }
            if ready == 0 { continue }
            try readAvailableOutput()
        }
    }

    private func readAvailableOutput() throws {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = read(terminal.fileDescriptor, &buffer, buffer.count)
        if count < 0 && errno == EINTR { return }
        // Linux PTYs report EIO when the application end closes, while Darwin reports EOF.
        if count == 0 || (count < 0 && errno == EIO) {
            throw TestApplicationError.endOfOutput(output: output)
        }
        guard count > 0 else {
            throw TestApplicationError.systemCall(operation: "read", code: errno)
        }
        output.append(contentsOf: buffer.prefix(count))
    }
}

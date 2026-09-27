import Dispatch
import Foundation

#if canImport(Darwin)
    import Darwin
    private typealias SpawnAttributes = posix_spawnattr_t?
#else
    import Glibc
    private typealias SpawnAttributes = posix_spawnattr_t
#endif

enum TestApplicationError: Error {
    case missingExecutable
    case systemCall(operation: String, code: Int32)
    case timedOut(output: Data)
    case endOfOutput(output: Data)
    case invalidUTF8
}

/// Launches a real executable attached to a terminal, like an app UI-test driver.
/// POSIX spawning avoids a weak-reference allocation leaked by Foundation.Process.run()
/// in the Linux Swift 6.4 toolchain when AddressSanitizer runs these tests.
final class TestApplication {
    private let executablePath: String
    private let arguments: [String]
    private let terminal: FileHandle
    private let applicationTerminal: FileHandle
    private var processID: pid_t?
    private var didTerminate = false
    private var output = Data()

    var isRunning: Bool { processID != nil && !didTerminate }

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
        self.executablePath = executablePath
        self.arguments = arguments
    }

    deinit {
        terminate()
    }

    func launch() throws {
        #if canImport(Darwin)
            var actions: posix_spawn_file_actions_t?
        #else
            var actions = posix_spawn_file_actions_t()
        #endif
        let result = posix_spawn_file_actions_init(&actions)
        guard result == 0 else {
            throw TestApplicationError.systemCall(operation: "posix_spawn_file_actions_init", code: result)
        }
        defer { posix_spawn_file_actions_destroy(&actions) }
        #if canImport(Darwin)
            var attributes: posix_spawnattr_t?
        #else
            var attributes = posix_spawnattr_t()
        #endif
        let attributeResult = posix_spawnattr_init(&attributes)
        guard attributeResult == 0 else {
            throw TestApplicationError.systemCall(operation: "posix_spawnattr_init", code: attributeResult)
        }
        defer { posix_spawnattr_destroy(&attributes) }
        try configureSignals(&attributes)
        for descriptor in [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO] {
            let result = posix_spawn_file_actions_adddup2(&actions, applicationTerminal.fileDescriptor, descriptor)
            guard result == 0 else {
                throw TestApplicationError.systemCall(operation: "posix_spawn_file_actions_adddup2", code: result)
            }
        }
        let strings = ([executablePath] + arguments).map { strdup($0) }
        defer {
            for string in strings { free(string) }
        }
        guard strings.allSatisfy({ $0 != nil }) else {
            throw TestApplicationError.systemCall(operation: "strdup", code: ENOMEM)
        }
        var argv = strings + [nil]
        var child: pid_t = 0
        let status = executablePath.withCString { path in
            argv.withUnsafeMutableBufferPointer { buffer in
                posix_spawn(&child, path, &actions, &attributes, buffer.baseAddress!, environ)
            }
        }
        guard status == 0 else { throw TestApplicationError.systemCall(operation: "posix_spawn", code: status) }
        processID = child
        try applicationTerminal.close()
    }

    private func configureSignals(_ attributes: inout SpawnAttributes) throws {
        // Tests may run with SIGTERM masked. A child must receive termination
        // promptly rather than forcing every shutdown through the timeout.
        var signals = sigset_t()
        sigemptyset(&signals)
        sigaddset(&signals, SIGTERM)
        let defaultResult = posix_spawnattr_setsigdefault(&attributes, &signals)
        guard defaultResult == 0 else {
            throw TestApplicationError.systemCall(operation: "posix_spawnattr_setsigdefault", code: defaultResult)
        }
        var mask = sigset_t()
        sigemptyset(&mask)
        let maskResult = posix_spawnattr_setsigmask(&attributes, &mask)
        guard maskResult == 0 else {
            throw TestApplicationError.systemCall(operation: "posix_spawnattr_setsigmask", code: maskResult)
        }
        let flagResult = posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK))
        guard flagResult == 0 else {
            throw TestApplicationError.systemCall(operation: "posix_spawnattr_setflags", code: flagResult)
        }
    }

    func terminate(timeout: TimeInterval = 2) {
        guard let processID, !didTerminate else { return }
        _ = kill(processID, SIGTERM)
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeout * 1_000_000_000)
        var status: Int32 = 0
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let result = waitpid(processID, &status, WNOHANG)
            if result == processID || (result == -1 && errno != EINTR) {
                didTerminate = true
                return
            }
            // Only this test harness waits for a child; do not occupy a Dispatch
            // worker that also runs application timers and parallel tests.
            usleep(1_000)
        }
        // A broken application must not leave a test runner waiting forever.
        _ = kill(processID, SIGKILL)
        while waitpid(processID, &status, 0) == -1 && errno == EINTR {}
        didTerminate = true
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

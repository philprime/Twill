import Dispatch
import Foundation

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

/// Owns a process group until its leader is reaped. Waiting observes exit without
/// reaping on a worker, so cancellation cannot signal an already-reused process ID.
@MainActor
final class CommandProcess {
    let identifier: pid_t
    private var reaped = false
    private static let terminationMask: Int32 = 0x7f
    private static let exitCodeMask: Int32 = 0xff
    private static let exitCodeShift: Int32 = 8

    init(arguments: [String], output: URL, errors: URL) throws {
        #if canImport(Darwin)
            var actions: posix_spawn_file_actions_t?
            var attributes: posix_spawnattr_t?
        #else
            var actions = posix_spawn_file_actions_t()
            var attributes = posix_spawnattr_t()
        #endif
        try Self.check(posix_spawn_file_actions_init(&actions))
        defer { posix_spawn_file_actions_destroy(&actions) }
        try Self.check(posix_spawnattr_init(&attributes))
        defer { posix_spawnattr_destroy(&attributes) }
        // Swift's executors can block signals on their worker threads. The
        // child needs a clean mask and default SIGTERM handling for cancellation.
        var signals = sigset_t()
        sigemptyset(&signals)
        try Self.check(posix_spawnattr_setsigmask(&attributes, &signals))
        sigaddset(&signals, SIGTERM)
        try Self.check(posix_spawnattr_setsigdefault(&attributes, &signals))
        var flags = Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF)
        #if canImport(Darwin)
            flags |= Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)
        #endif
        try Self.check(posix_spawnattr_setflags(&attributes, flags))
        try Self.check(posix_spawnattr_setpgroup(&attributes, 0))
        // Background process groups must not read the controlling terminal,
        // which would stop Linux children with SIGTTIN instead of completing.
        try Self.check(posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0))
        try Self.check(
            posix_spawn_file_actions_addopen(
                &actions, STDOUT_FILENO, output.path, O_WRONLY | O_CREAT | O_TRUNC, 0o600))
        try Self.check(
            posix_spawn_file_actions_addopen(
                &actions, STDERR_FILENO, errors.path, O_WRONLY | O_CREAT | O_TRUNC, 0o600))
        #if os(Linux)
            try Self.check(posix_spawn_file_actions_addclosefrom_np(&actions, STDERR_FILENO + 1))
        #endif
        var argv = (["/usr/bin/env"] + arguments).map { strdup($0) } + [nil]
        var environment = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            for argument in argv { free(argument) }
            for variable in environment { free(variable) }
        }
        guard argv.dropLast().allSatisfy({ $0 != nil }), environment.dropLast().allSatisfy({ $0 != nil }) else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOMEM))
        }
        var child = pid_t()
        try Self.check(posix_spawn(&child, "/usr/bin/env", &actions, &attributes, &argv, &environment))
        identifier = child
    }

    func waitForExit() async throws -> Int32 {
        let child = identifier
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                DispatchQueue.global().async { @Sendable in
                    var information = siginfo_t()
                    var result: Int32
                    repeat {
                        result = waitid(P_PID, id_t(child), &information, WEXITED | WNOWAIT)
                    } while result == -1 && errno == EINTR
                    if result == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(domain: NSPOSIXErrorDomain, code: Int(errno)))
                    }
                }
            }
            var status: Int32 = 0
            var result: pid_t
            repeat {
                result = waitpid(child, &status, 0)
            } while result == -1 && errno == EINTR
            reaped = true
            if result == -1 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
            try Task.checkCancellation()
            let signal = status & Self.terminationMask
            return signal == 0 ? (status >> Self.exitCodeShift) & Self.exitCodeMask : signal
        } onCancel: {
            Task { @MainActor in
                if !self.reaped { _ = kill(-self.identifier, SIGTERM) }
            }
        }
    }

    private static func check(_ result: Int32) throws {
        if result != 0 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(result)) }
    }
}

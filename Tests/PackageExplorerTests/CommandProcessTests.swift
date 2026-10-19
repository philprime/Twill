import Foundation
import Testing

@testable import PackageExplorer

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Command process ownership")
@MainActor
struct CommandProcessTests {
    @Test("Arguments remain literal and stdout is fully written before completion")
    func arguments() async throws {
        // -- Arrange --
        let logs = try workspace()
        defer { try? FileManager.default.removeItem(at: logs) }
        let output = logs.appendingPathComponent("stdout")
        let errors = logs.appendingPathComponent("stderr")
        let literal = "type name; $(not-a-command)"
        let process = try CommandProcess(arguments: ["/usr/bin/printf", "%s", literal], output: output, errors: errors)

        // -- Act --
        let status = try await process.waitForExit()
        let text = try read(output)

        // -- Assert --
        #expect(status == 0)
        #expect(text == literal)
        #expect(try read(errors).isEmpty)
    }

    @Test("Noninteractive children read stdin from the null device")
    func standardInput() async throws {
        // -- Arrange --
        let logs = try workspace()
        defer { try? FileManager.default.removeItem(at: logs) }
        let process = try CommandProcess(
            arguments: ["/bin/sh", "-c", "test /dev/null -ef /dev/stdin"],
            output: logs.appendingPathComponent("stdout"), errors: logs.appendingPathComponent("stderr"))

        // -- Act --
        let status = try await process.waitForExit()

        // -- Assert --
        #expect(status == 0)
    }

    @Test("Exit status and stderr remain separate from stdout")
    func failure() async throws {
        // -- Arrange --
        let logs = try workspace()
        defer { try? FileManager.default.removeItem(at: logs) }
        let output = logs.appendingPathComponent("stdout")
        let errors = logs.appendingPathComponent("stderr")
        let process = try CommandProcess(
            arguments: ["/bin/sh", "-c", "printf diagnostic >&2; exit 7"], output: output, errors: errors)

        // -- Act --
        let status = try await process.waitForExit()

        // -- Assert --
        #expect(status == 7)
        #expect(try read(output).isEmpty)
        #expect(try read(errors) == "diagnostic")
    }

    @Test("Cancellation joins and reaps an already launched child", .timeLimit(.minutes(1)))
    func cancellation() async throws {
        // -- Arrange --
        let logs = try workspace()
        defer { try? FileManager.default.removeItem(at: logs) }
        // The child blocks until cancellation. The test itself never sleeps.
        let process = try CommandProcess(
            arguments: ["/bin/sleep", "60"], output: logs.appendingPathComponent("stdout"),
            errors: logs.appendingPathComponent("stderr"))

        // -- Act --
        let task = Task { try await process.waitForExit() }
        task.cancel()

        // -- Assert --
        await #expect(throws: CancellationError.self) { try await task.value }
        let result = kill(process.identifier, 0)
        let error = errno
        #expect(result == -1)
        #expect(error == ESRCH)
    }

    private func workspace() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func read(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try #require(String(bytes: try handle.readToEnd() ?? Data(), encoding: .utf8))
    }
}

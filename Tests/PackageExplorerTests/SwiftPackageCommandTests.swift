import Foundation
import Testing

@testable import PackageExplorer

@Suite("Swift command lifecycle")
@MainActor
struct SwiftPackageCommandTests {
    @Test("A failed Swift command reports its exit status and compiler diagnostics")
    func failure() async throws {
        // -- Arrange --
        let logs = try workspace()
        defer { try? FileManager.default.removeItem(at: logs) }

        // -- Act --
        do {
            _ = try await SwiftPackageCommand().run(
                ["package", "--package-path", logs.path, "describe", "--type", "json"], logs: logs)
            Issue.record("Expected Swift to reject a directory without a manifest")
        } catch PackageExplorerError.commandFailed(_, let status, let output) {
            // -- Assert --
            #expect(status != 0)
            #expect(output.contains("Package.swift"))
        }
    }

    @Test("Cancellation before launch starts no process and creates no output files")
    func cancellation() async throws {
        // -- Arrange --
        let logs = try workspace()
        defer { try? FileManager.default.removeItem(at: logs) }
        let command = SwiftPackageCommand()
        let task = Task { try await command.run(["--version"], logs: logs) }

        // -- Act --
        task.cancel()

        // -- Assert --
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try FileManager.default.contentsOfDirectory(atPath: logs.path).isEmpty)
    }

    private func workspace() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

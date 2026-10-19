import Foundation

/// Uses regular files instead of pipes so verbose compiler output cannot deadlock
/// while awaiting process completion. Only argument arrays reach the executable.
@MainActor
final class SwiftPackageCommand {
    func run(_ arguments: [String], logs: URL) async throws -> String {
        try Task.checkCancellation()
        let outputURL = logs.appendingPathComponent(UUID().uuidString + ".stdout")
        let errorURL = logs.appendingPathComponent(UUID().uuidString + ".stderr")
        let child = try CommandProcess(arguments: ["swift"] + arguments, output: outputURL, errors: errorURL)
        let status = try await child.waitForExit()
        let stdout = try readOutput(at: outputURL)
        guard status == 0 else {
            let stderr = try readOutput(at: errorURL)
            throw PackageExplorerError.commandFailed(
                arguments: arguments, status: status, output: String((stderr + stdout).suffix(12_000)))
        }
        return stdout
    }

    private func readOutput(at url: URL) throws -> String {
        // Explicit handle ownership also avoids FoundationEssentials' empty-file
        // String(contentsOf:) allocation leak on the Linux Swift 6.4 toolchain.
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        guard let text = String(bytes: try input.readToEnd() ?? Data(), encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return text
    }
}

import Foundation

/// Uses regular files instead of pipes so verbose compiler output cannot deadlock
/// while awaiting process completion. Only argument arrays reach the executable.
@MainActor
final class SwiftPackageCommand {
    private var process: Process?

    func run(_ arguments: [String], logs: URL) async throws -> String {
        try Task.checkCancellation()
        let outputURL = logs.appendingPathComponent(UUID().uuidString + ".stdout")
        let errorURL = logs.appendingPathComponent(UUID().uuidString + ".stderr")
        try Data().write(to: outputURL)
        try Data().write(to: errorURL)
        let output = try FileHandle(forWritingTo: outputURL)
        let errors = try FileHandle(forWritingTo: errorURL)
        defer {
            try? output.close()
            try? errors.close()
            process = nil
        }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        child.arguments = ["swift"] + arguments
        child.standardOutput = output
        child.standardError = errors
        process = child
        let status: Int32 = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                child.terminationHandler = { finished in
                    // swift-corelibs-foundation retains a Process run-loop source until
                    // waitUntilExit releases it. The child has already exited here, so
                    // this only finishes cleanup on the callback thread, without polling.
                    finished.waitUntilExit()
                    continuation.resume(returning: finished.terminationStatus)
                }
                do { try child.run() } catch { continuation.resume(throwing: error) }
            }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
        // Cancellation is observed after the child exits so owned work is joined
        // before the loader removes its temporary build and output files.
        try Task.checkCancellation()
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

    private func cancel() {
        if let process, process.isRunning { process.terminate() }
    }
}

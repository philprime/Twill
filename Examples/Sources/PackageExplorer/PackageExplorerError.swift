import Foundation

enum PackageExplorerError: LocalizedError {
    case invalidManifest(String)
    case commandFailed(arguments: [String], status: Int32, output: String)
    case noSymbolGraphs

    var errorDescription: String? {
        switch self {
        case .invalidManifest(let path): "Expected an existing Package.swift file: \(path)"
        case .commandFailed(let arguments, let status, let output):
            "swift \(arguments.joined(separator: " ")) exited with status \(status).\n\(output)"
        case .noSymbolGraphs: "The build produced no Swift symbol graphs."
        }
    }
}

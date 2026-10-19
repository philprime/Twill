import Foundation
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@main
struct PackageExplorer {
    @MainActor
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("PackageExplorer: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    @MainActor
    private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] || arguments == ["-h"] {
            print(
                """
                Usage: PackageExplorer /path/to/Package.swift

                Builds a trusted Swift package and explores its own type symbols.
                Building can execute package plugins and macros, and resolve dependencies.
                Requires Swift on PATH and a Kitty graphics-compatible terminal.

                /: search    Tab: move between controls    Arrows: select types
                +/-: zoom    WASD: pan    0: fit    Ctrl-C: quit

                Colors identify modules. Edges show inheritance (gold),
                conformance (green), and nesting (blue). The selected type's
                label and declaration appear as terminal text, not bitmap text.
                """)
            return
        }
        guard arguments.count == 1 else {
            throw PackageExplorerError.invalidManifest("Usage: PackageExplorer /path/to/Package.swift")
        }
        let manifest = URL(fileURLWithPath: NSString(string: arguments[0]).expandingTildeInPath).standardizedFileURL
        print("Building trusted package: \(manifest.path)")
        let package = try await PackageLoader().load(manifest: manifest) { print($0) }
        try await Twill.Application(rootView: PackageExplorerView(package: package)).run()
    }
}

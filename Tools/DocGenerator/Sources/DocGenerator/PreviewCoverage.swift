import Foundation

@MainActor
enum PreviewCoverage {
    /// Rejects incomplete fixture sets so adding a public view cannot silently omit its documentation preview.
    static func validate(_ fixtures: [DocumentationPreviewFixture], root: URL) throws {
        let symbols = Set(fixtures.map(\.symbol))
        guard symbols.count == fixtures.count else {
            throw GenerationError("Preview fixture symbols must be unique")
        }
        let views = root.appendingPathComponent("Sources/Twill/Views")
        let files = try FileManager.default.contentsOfDirectory(at: views, includingPropertiesForKeys: nil)
        let pattern = try NSRegularExpression(
            pattern: #"public (?:struct|enum|class)\s+(\w+)(?:<[^{}]*>)?\s*:\s*View\b[^{]*\{"#)
        var names = Set<String>()
        for file in files where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in pattern.matches(in: source, range: range) {
                if let nameRange = Range(match.range(at: 1), in: source) { names.insert(String(source[nameRange])) }
            }
        }
        guard names == symbols else {
            let missing = names.subtracting(symbols).sorted().joined(separator: ", ")
            let extra = symbols.subtracting(names).sorted().joined(separator: ", ")
            throw GenerationError("Preview coverage mismatch. Missing: [\(missing)]. Unknown: [\(extra)].")
        }
    }
}

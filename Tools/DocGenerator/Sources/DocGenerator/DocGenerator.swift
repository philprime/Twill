import Foundation

// The tool build enables testability to render snapshots without exposing runtime internals as public API.
@testable import Twill

@main
@MainActor
struct DocGenerator {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            throw GenerationError("Usage: DocGenerator <repository-root>")
        }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let fixtures = DocumentationPreviewFixture.all
        try PreviewCoverage.validate(fixtures, root: root)
        let catalog = root.appendingPathComponent("Sources/Twill/Twill.docc")
        let resources = catalog.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try DocumentationPreviewFixture.imageData.write(to: resources.appendingPathComponent("terminal-sample.png"))
        var gallery = galleryHeader
        for fixture in fixtures {
            let svg = try await render(fixture)
            let filename = "preview-\(fixture.symbol).svg"
            try svg.write(to: resources.appendingPathComponent(filename), atomically: true, encoding: .utf8)
            gallery +=
                "\n## \(fixture.symbol)\n\n``\(fixture.symbol)``\n\n\(fixture.description)\n\n"
                + "![\(fixture.symbol) terminal preview](\(filename))\n"
        }
        try gallery.write(to: catalog.appendingPathComponent("ViewGallery.md"), atomically: true, encoding: .utf8)
        print("Generated \(fixtures.count) view previews and ViewGallery.md")
    }

    private static func render(_ fixture: DocumentationPreviewFixture) async throws -> String {
        let tasks = MountedTaskRegistry()
        let renderer = try fixture.makeRenderer(tasks)
        let initial = renderer.render(DocumentationPreviewFixture.date, proposal: fixture.proposal)
        for key in fixture.keys { _ = renderer.handle(key) }
        let grid =
            fixture.keys.isEmpty
            ? initial.grid : renderer.render(DocumentationPreviewFixture.date, proposal: fixture.proposal).grid
        let svg = DocumentationPreviewSVG.render(grid, caret: renderer.caretPosition, title: fixture.symbol)
        let repeated = renderer.render(DocumentationPreviewFixture.date, proposal: fixture.proposal).grid
        renderer.unmount()
        tasks.cancelAll()
        await tasks.join()
        guard grid == repeated else {
            throw GenerationError("\(fixture.symbol) changed at the same snapshot date")
        }
        if fixture.symbol == "EmptyView" {
            guard grid == nil || grid?.size == CellSize.zero else {
                throw GenerationError("EmptyView unexpectedly produced content")
            }
        } else if grid == nil {
            throw GenerationError("\(fixture.symbol) did not produce a preview")
        }
        if fixture.symbol == "ImageView", grid?.images.count != 1 || !svg.contains("data:image/png;base64,") {
            throw GenerationError("ImageView did not produce an embedded PNG preview")
        }
        return svg
    }

    private static var galleryHeader: String {
        """
        # View gallery

        Explore terminal views through snapshots produced by real Twill renderer instances.

        ## Overview

        These previews use a fixed date and a dark documentation theme. Terminal fonts and ANSI
        palettes vary. Reverse video indicates focus, and an underline represents the terminal caret.
        Each preview uses the content's natural size unless its description specifies a viewport.
        Images show one state, rather than interactive behavior. Tab and Shift-Tab move between controls.
        Up and Down navigate according to the focused control's keyboard behavior.

        The gallery includes layout and composition types, controls, and modifier wrappers. Wrappers that
        add behavior without visual decoration show their underlying content. EmptyView is intentionally blank.

        """
    }
}

struct GenerationError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

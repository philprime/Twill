import Foundation
import Testing

@testable import Twill

@Suite("Large document editing efficiency")
@MainActor
struct EditorEfficiencyTests {
    @Test("Large mixed-width documents edit locally with bounded binding reads", arguments: [24, 1000])
    func editsPreserveGraphemes(lineCount: Int) {
        // -- Arrange --
        let line = "界é👩🏽‍💻"
        let original = String(repeating: line + "\n", count: lineCount - 1) + line
        var text = original
        var reads = 0
        let renderer = ViewRenderer.make(
            TextEditor(
                text: Binding(
                    get: {
                        reads += 1
                        return text
                    }, set: { text = $0 })
            )
            .frame(width: 20, height: 3))
        defer { renderer.unmount() }
        _ = renderer.render(.now)
        reads = 0

        // -- Act --
        _ = renderer.handle(.arrowLeft)
        renderer.refreshContent(at: .now)
        _ = renderer.handle(.x)
        _ = renderer.render(.now)
        let inserted = text
        let editReads = reads
        _ = renderer.handle(.backspace)
        let restored = renderer.render(.now)

        // -- Assert --
        #expect(inserted == String(original.dropLast()) + "x👩🏽‍💻")
        #expect(text == original)
        #expect(editReads <= 24)
        #expect(renderer.caretPosition == CellPosition(column: 3, row: 2))
        #expect(restored.grid?.size == CellSize(width: 20, height: 3))
        #expect(restored.nextUpdate == nil)
    }
}

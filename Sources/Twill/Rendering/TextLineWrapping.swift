/// Word boundaries affect only wrapping. Source ranges retain original offsets
/// so head and middle truncation can recover text omitted by later wrapped rows.
struct TextLineWrapping {
    private typealias Glyph = TextDrawing.Glyph

    /// Editing callers retain separators so every model offset stays navigable.
    func ranges(
        for glyphs: [TextDrawing.Glyph], width: Int?, mode: Text.LineBreakMode, preservesSpaces: Bool = false
    ) -> [Range<Int>] {
        guard let width, mode != .clipping else { return [glyphs.indices] }
        guard width > 0 else { return [] }
        guard !glyphs.isEmpty else { return [glyphs.indices] }
        var result: [Range<Int>] = []
        var start = 0
        while start < glyphs.count {
            let range = rowRange(
                glyphs, from: start, width: width, words: mode == .wordWrapping,
                preservesSpaces: preservesSpaces)
            result.append(start..<range.end)
            start = range.next
        }
        return result
    }

    private func rowRange(
        _ glyphs: [Glyph], from start: Int, width: Int, words: Bool, preservesSpaces: Bool
    ) -> (end: Int, next: Int) {
        var end = start
        var columns = 0
        var wordBoundary: Int?
        while end < glyphs.count, columns + glyphs[end].width <= width {
            if words, glyphs[end].character == " " {
                if preservesSpaces {
                    wordBoundary = end + 1
                } else if end > start, glyphs[end - 1].character != " " {
                    wordBoundary = end
                }
            }
            columns += glyphs[end].width
            end += 1
        }
        if end == glyphs.count { return (end, end) }
        // Oversized graphemes occupy one clipped row, never partial cells.
        if end == start { return (start + 1, start + 1) }
        if words, !preservesSpaces, glyphs[end].character == " " {
            return (trimmedEnd(glyphs, from: start, to: end), afterSpaces(glyphs, from: end))
        }
        if let boundary = wordBoundary {
            return (boundary, preservesSpaces ? boundary : afterSpaces(glyphs, from: boundary))
        }
        return (end, end)
    }

    private func afterSpaces(_ glyphs: [Glyph], from start: Int) -> Int {
        var end = start
        while end < glyphs.count, glyphs[end].character == " " { end += 1 }
        return end
    }

    private func trimmedEnd(_ glyphs: [Glyph], from start: Int, to end: Int) -> Int {
        var trimmed = end
        while trimmed > start, glyphs[trimmed - 1].character == " " { trimmed -= 1 }
        return trimmed
    }
}

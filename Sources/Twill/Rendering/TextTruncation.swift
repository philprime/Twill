/// Ellipsis insertion uses the same sanitized terminal-cell geometry as text.
struct TextTruncation {
    typealias Glyph = TextDrawing.Glyph
    private static let ellipsis: Glyph = ("…", TerminalCharacterWidth.columns(for: "…"))

    func apply(_ glyphs: [Glyph], width: Int, mode: Text.TruncationMode) -> [Glyph] {
        guard width >= Self.ellipsis.width else { return [] }
        let available = width - Self.ellipsis.width
        switch mode {
        case .tail: return prefix(glyphs, width: available) + [Self.ellipsis]
        case .head: return [Self.ellipsis] + prefix(Array(glyphs.reversed()), width: available).reversed()
        case .middle:
            let start = prefix(glyphs, width: (available + 1) / 2)
            let end = prefix(Array(glyphs.dropFirst(start.count).reversed()), width: available / 2).reversed()
            return start + [Self.ellipsis] + end
        }
    }

    private func prefix(_ glyphs: [Glyph], width: Int) -> [Glyph] {
        var result: [Glyph] = []
        var columns = 0
        for glyph in glyphs {
            guard columns + glyph.width <= width else { break }
            result.append(glyph)
            columns += glyph.width
        }
        return result
    }
}

/// The emergency fallback is deliberately limited to printable basic Latin.
/// Unsupported graphemes become a visible question mark, never invisible ink.
struct BitmapTextRenderer {
    private static let glyphSize = 8
    private static let baseline = 7.0

    func layout(_ text: String, style: TextStyle) -> TextLayout {
        let characters = text.map { character -> Int in
            guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first,
                (32...126).contains(scalar.value)
            else { return 63 }
            return Int(scalar.value)
        }
        let advance = style.size
        let scale = advance / Double(Self.glyphSize)
        let width = Int((advance * Double(characters.count)).rounded(.up))
        let height = Int(advance.rounded(.up))
        var pixels = Array(repeating: UInt8(0), count: width * height)
        var hasInk = false
        for row in 0..<height {
            let glyphRow = min(Self.glyphSize - 1, Int(Double(row) / scale))
            for column in 0..<width {
                let sourceX = Int(Double(column) / scale)
                let characterIndex = min(characters.count - 1, sourceX / Self.glyphSize)
                let glyphColumn = sourceX % Self.glyphSize
                let bits = BasicLatinFont.rows[(characters[characterIndex] - 32) * Self.glyphSize + glyphRow]
                let normal = bits & (1 << glyphColumn) != 0
                let bold = style.weight == .bold && glyphColumn > 0 && bits & (1 << (glyphColumn - 1)) != 0
                if normal || bold {
                    pixels[row * width + column] = 255
                    hasInk = true
                }
            }
        }
        return TextLayout(
            width: advance * Double(characters.count), height: advance,
            firstBaseline: Self.baseline * scale,
            bitmap: hasInk
                ? TextBitmap(width: width, height: height, coverage: pixels)
                : TextBitmap(width: 0, height: 0, coverage: []))
    }
}

package struct TextLayout: Sendable {
    package static let empty = TextLayout(
        width: 0, height: 0, firstBaseline: 0, bitmap: TextBitmap(width: 0, height: 0, coverage: []))

    package let width: Double
    package let height: Double
    package let firstBaseline: Double
    package let bitmap: TextBitmap

    package init(width: Double, height: Double, firstBaseline: Double, bitmap: TextBitmap) {
        self.width = width
        self.height = height
        self.firstBaseline = firstBaseline
        self.bitmap = bitmap
    }
}

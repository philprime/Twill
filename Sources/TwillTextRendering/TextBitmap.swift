/// Coverage is independent of color so the canvas can apply its drawing state.
/// The origin is relative to the layout box and can be negative for glyph overhang.
package struct TextBitmap: Sendable {
    package let width: Int
    package let height: Int
    package let originX: Double
    package let originY: Double
    package let coverage: [UInt8]

    package init(
        width: Int, height: Int, originX: Double = 0, originY: Double = 0,
        coverage: [UInt8]
    ) {
        self.width = width
        self.height = height
        self.originX = originX
        self.originY = originY
        self.coverage = coverage
    }
}

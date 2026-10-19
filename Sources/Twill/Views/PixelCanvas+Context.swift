import Foundation

extension PixelCanvas {
    /// A value-owned bitmap. Pixel centers are at half-integer coordinates.
    /// All drawing clips to its bounds and uses source-over alpha compositing.
    public struct Context: Sendable {
        /// The bitmap's resolution.
        public let size: PixelSize
        private var bytes: [UInt8]

        /// Creates a transparent bitmap.
        public init(size: PixelSize) {
            self.size = size
            bytes = Array(repeating: 0, count: size.width * size.height * 4)
        }

        /// Row-major, tightly packed, straight-alpha RGBA bytes.
        public var rgbaData: Data { Data(bytes) }

        /// Replaces every pixel, including alpha. Use clear to reset the bitmap.
        public mutating func fill(_ color: PixelColor) {
            for offset in stride(from: 0, to: bytes.count, by: 4) {
                bytes[offset] = color.red
                bytes[offset + 1] = color.green
                bytes[offset + 2] = color.blue
                bytes[offset + 3] = color.alpha
            }
        }

        /// Composites one pixel. Coordinates outside the bitmap are ignored.
        public mutating func draw(_ color: PixelColor, x pixelX: Int, y pixelY: Int) {
            guard pixelX >= 0 && pixelX < size.width && pixelY >= 0 && pixelY < size.height else { return }
            let offset = (pixelY * size.width + pixelX) * 4
            let sourceAlpha = Double(color.alpha) / 255
            let destinationAlpha = Double(bytes[offset + 3]) / 255
            let alpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)
            guard alpha > 0 else { return }
            let channels = [color.red, color.green, color.blue]
            for channel in 0..<3 {
                let value =
                    (Double(channels[channel]) * sourceAlpha
                        + Double(bytes[offset + channel]) * destinationAlpha * (1 - sourceAlpha)) / alpha
                bytes[offset + channel] = UInt8(clamping: Int(value.rounded()))
            }
            bytes[offset + 3] = UInt8(clamping: Int((alpha * 255).rounded()))
        }

        /// Fills an integer-aligned rectangle using source-over compositing.
        public mutating func fillRectangle(x pixelX: Int, y pixelY: Int, width: Int, height: Int, color: PixelColor) {
            precondition(width >= 0 && height >= 0)
            let right = pixelX.addingReportingOverflow(width)
            let bottom = pixelY.addingReportingOverflow(height)
            precondition(!right.overflow && !bottom.overflow)
            let left = min(size.width, max(0, pixelX))
            let top = min(size.height, max(0, pixelY))
            for row in top..<max(top, min(size.height, bottom.partialValue)) {
                for column in left..<max(left, min(size.width, right.partialValue)) {
                    draw(color, x: column, y: row)
                }
            }
        }

        /// Fills an antialiased circle, clipped before rasterization.
        public mutating func fillCircle(center: PixelPoint, radius: Double, color: PixelColor) {
            precondition(center.horizontal.isFinite && center.vertical.isFinite && radius.isFinite && radius >= 0)
            guard radius > 0 else { return }
            rasterize(
                minimum: PixelPoint(x: center.horizontal - radius - 1, y: center.vertical - radius - 1),
                maximum: PixelPoint(x: center.horizontal + radius + 1, y: center.vertical + radius + 1), color: color
            ) { pixelX, pixelY in
                radius + 0.5 - hypot(pixelX - center.horizontal, pixelY - center.vertical)
            }
        }

        /// Strokes an antialiased line segment with round caps.
        /// A zero-length segment draws a disk with half the stroke width.
        public mutating func strokeLine(
            from start: PixelPoint, to end: PixelPoint, color: PixelColor, width: Double = 1
        ) {
            precondition(
                start.horizontal.isFinite && start.vertical.isFinite && end.horizontal.isFinite && end.vertical.isFinite
            )
            precondition(width.isFinite && width >= 0)
            guard width > 0 else { return }
            let radius = width / 2
            let deltaX = end.horizontal - start.horizontal
            let deltaY = end.vertical - start.vertical
            let lengthSquared = deltaX * deltaX + deltaY * deltaY
            rasterize(
                minimum: PixelPoint(
                    x: min(start.horizontal, end.horizontal) - radius - 1,
                    y: min(start.vertical, end.vertical) - radius - 1),
                maximum: PixelPoint(
                    x: max(start.horizontal, end.horizontal) + radius + 1,
                    y: max(start.vertical, end.vertical) + radius + 1), color: color
            ) { pixelX, pixelY in
                let projection =
                    lengthSquared > 0
                    ? min(
                        1,
                        max(
                            0,
                            ((pixelX - start.horizontal) * deltaX + (pixelY - start.vertical) * deltaY) / lengthSquared)
                    ) : 0
                return radius + 0.5
                    - hypot(
                        pixelX - start.horizontal - projection * deltaX, pixelY - start.vertical - projection * deltaY)
            }
        }

        private mutating func rasterize(
            minimum: PixelPoint, maximum: PixelPoint, color: PixelColor,
            coverage: (Double, Double) -> Double
        ) {
            let left = Int(max(0, min(Double(size.width), floor(minimum.horizontal))))
            let right = Int(max(0, min(Double(size.width), ceil(maximum.horizontal))))
            let top = Int(max(0, min(Double(size.height), floor(minimum.vertical))))
            let bottom = Int(max(0, min(Double(size.height), ceil(maximum.vertical))))
            for pixelY in top..<bottom {
                for pixelX in left..<right {
                    let amount = min(1, max(0, coverage(Double(pixelX) + 0.5, Double(pixelY) + 0.5)))
                    let alpha = UInt8(clamping: Int((Double(color.alpha) * amount).rounded()))
                    draw(
                        PixelColor(red: color.red, green: color.green, blue: color.blue, alpha: alpha), x: pixelX,
                        y: pixelY)
                }
            }
        }
    }
}

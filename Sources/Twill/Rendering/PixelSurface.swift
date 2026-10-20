import Foundation

/// Shared only by UI-actor drawing contexts for one presentation. Context copies
/// own their graphics state, while all operations composite into this fixed destination.
@MainActor
final class PixelSurface {
    let size: PixelSize
    private var bytes: [UInt8]
    private static let samplesPerAxis = 4

    init(size: PixelSize) {
        self.size = size
        bytes = Array(repeating: 0, count: size.width * size.height * 4)
    }

    var rgbaData: Data { Data(bytes) }

    func paint(
        bounds: PixelPathBounds, color: PixelColor, opacity: Double,
        horizontalRange: ((Int) -> ClosedRange<Double>?)? = nil,
        coverage coverageAt: (PixelPoint) -> Double
    ) {
        guard color.alpha > 0 && opacity > 0 else { return }
        let left = Int(max(0, min(Double(size.width), floor(bounds.minimumX))))
        let right = Int(max(0, min(Double(size.width), ceil(bounds.maximumX))))
        let top = Int(max(0, min(Double(size.height), floor(bounds.minimumY))))
        let bottom = Int(max(0, min(Double(size.height), ceil(bounds.maximumY))))
        guard left < right && top < bottom else { return }
        let samples = Self.samplesPerAxis
        for row in top..<bottom {
            var rowLeft = left
            var rowRight = right
            if let horizontalRange {
                guard let range = horizontalRange(row) else { continue }
                rowLeft = Int(max(Double(left), min(Double(right), floor(range.lowerBound))))
                rowRight = Int(max(Double(left), min(Double(right), ceil(range.upperBound))))
            }
            guard rowLeft < rowRight else { continue }
            for column in rowLeft..<rowRight {
                var covered = 0.0
                // These loops run for every candidate pixel. Explicit indices
                // avoid generic iterator machinery in unoptimized playgrounds.
                var sampleRow = 0
                while sampleRow < samples {
                    var sampleColumn = 0
                    while sampleColumn < samples {
                        let point = PixelPoint(
                            x: Double(column) + (Double(sampleColumn) + 0.5) / Double(samples),
                            y: Double(row) + (Double(sampleRow) + 0.5) / Double(samples))
                        covered += coverageAt(point)
                        sampleColumn += 1
                    }
                    sampleRow += 1
                }
                let coverage = covered / Double(samples * samples)
                composite(
                    color, alpha: Double(color.alpha) / 255 * opacity * coverage,
                    offset: (row * size.width + column) * 4)
            }
        }
    }

    private func composite(_ color: PixelColor, alpha sourceAlpha: Double, offset: Int) {
        guard sourceAlpha > 0 else { return }
        let destinationAlpha = Double(bytes[offset + 3]) / 255
        let alpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)
        var channel = 0
        while channel < 3 {
            let source = channel == 0 ? color.red : channel == 1 ? color.green : color.blue
            let value =
                (Double(source) * sourceAlpha
                    + Double(bytes[offset + channel]) * destinationAlpha * (1 - sourceAlpha)) / alpha
            bytes[offset + channel] = UInt8(clamping: Int(value.rounded()))
            channel += 1
        }
        bytes[offset + 3] = UInt8(clamping: Int((alpha * 255).rounded()))
    }
}

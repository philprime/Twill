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
        contains: (PixelPoint) -> Bool
    ) {
        guard color.alpha > 0 && opacity > 0 else { return }
        let left = Int(max(0, min(Double(size.width), floor(bounds.minimumX))))
        let right = Int(max(0, min(Double(size.width), ceil(bounds.maximumX))))
        let top = Int(max(0, min(Double(size.height), floor(bounds.minimumY))))
        let bottom = Int(max(0, min(Double(size.height), ceil(bounds.maximumY))))
        guard left < right && top < bottom else { return }
        let samples = Self.samplesPerAxis
        for row in top..<bottom {
            for column in left..<right {
                var covered = 0
                for sampleRow in 0..<samples {
                    for sampleColumn in 0..<samples {
                        let point = PixelPoint(
                            x: Double(column) + (Double(sampleColumn) + 0.5) / Double(samples),
                            y: Double(row) + (Double(sampleRow) + 0.5) / Double(samples))
                        if contains(point) { covered += 1 }
                    }
                }
                let coverage = Double(covered) / Double(samples * samples)
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
        for (channel, source) in [color.red, color.green, color.blue].enumerated() {
            let value =
                (Double(source) * sourceAlpha
                    + Double(bytes[offset + channel]) * destinationAlpha * (1 - sourceAlpha)) / alpha
            bytes[offset + channel] = UInt8(clamping: Int(value.rounded()))
        }
        bytes[offset + 3] = UInt8(clamping: Int((alpha * 255).rounded()))
    }
}

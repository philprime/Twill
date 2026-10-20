import Foundation
import Testing

@testable import Twill

@Suite("Stroke raster work bounds")
@MainActor
struct PixelStrokeBoundsTests {
    @Test("A long diagonal visits a narrow strip rather than its bounding rectangle")
    func diagonalWork() {
        // -- Arrange --
        let path = Path { path in
            path.move(to: .init(x: 0, y: 0))
            path.addLine(to: .init(x: 1000, y: 1000))
        }
        let bounds = PixelStrokeBounds(path: PixelRasterPath(path), radius: 1)
        var candidateWidth = 0.0

        // -- Act --
        for row in 0..<1000 {
            if let range = bounds.horizontalRange(for: row) {
                candidateWidth += range.upperBound - range.lowerBound
            }
        }

        // -- Assert --
        #expect(candidateWidth > 1000)
        #expect(candidateWidth < 6000)
        #expect(bounds.horizontalRange(for: 1002) == nil)
    }

    @Test("Surface sampling obeys the stroke candidate budget")
    func sampledWork() {
        // -- Arrange --
        let path = Path { path in
            path.move(to: .init(x: 0, y: 0))
            path.addLine(to: .init(x: 64, y: 64))
        }
        let raster = PixelRasterPath(path)
        let bounds = PixelStrokeBounds(path: raster, radius: 1)
        let surface = PixelSurface(size: .init(width: 64, height: 64))
        var samples = 0

        // -- Act --
        surface.paint(
            bounds: .init(minimumX: 0, minimumY: 0, maximumX: 64, maximumY: 64),
            color: .init(red: 255, green: 0, blue: 0), opacity: 1,
            horizontalRange: bounds.horizontalRange(for:),
            coverage: { point in
                samples += 1
                return raster.containsStroke(point, radius: 1) ? 1 : 0
            })

        // -- Assert --
        #expect(samples > 64 * 16)
        #expect(samples < 64 * 6 * 16)
        #expect(surface.rgbaData[4 * (32 * 64 + 32) + 3] == 255)
        #expect(surface.rgbaData[4 * (32 * 64 + 5) + 3] == 0)
    }

    @Test("Horizontal, vertical, and zero-length segments retain their round caps")
    func axisAlignedAndDegenerate() {
        // -- Arrange --
        let endpoints: [(PixelPoint, PixelPoint)] = [
            (.init(x: 2, y: 3), .init(x: 8, y: 3)),
            (.init(x: 4, y: 2), .init(x: 4, y: 8)),
            (.init(x: 2, y: 3), .init(x: 2, y: 3)),
        ]

        // -- Act --
        let ranges = endpoints.map { start, end in
            let path = Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            return PixelStrokeBounds(path: PixelRasterPath(path), radius: 0.5).horizontalRange(for: 3)
        }

        // -- Assert --
        #expect(ranges == [1.5...8.5, 3.5...4.5, 1.5...2.5])
    }

    @Test("Culled strokes match full-surface sampling with transforms and clipping", arguments: 0..<4)
    func coverageMatchesReference(transformation: Int) {
        // -- Arrange --
        let path = Path { path in
            path.move(to: .init(x: 2, y: 2))
            path.addLine(to: .init(x: 18, y: 13))
            path.addLine(to: .init(x: 2, y: 13))
            path.closeSubpath()
            path.move(to: .init(x: 4, y: 8))
            path.addLine(to: .init(x: 17, y: 3))
            path.move(to: .init(x: 10, y: 8))
            path.addLine(to: .init(x: 10, y: 8))
            path.addEllipse(in: .init(x: 5, y: 4, width: 8, height: 6))
        }
        let size = PixelSize(width: 32, height: 24)
        let actual = PixelSurface(size: size)
        let reference = PixelSurface(size: size)
        var context = PixelCanvas.Context(surface: actual)
        let clip = Path(PixelRect(x: 3, y: 2, width: 23, height: 18))
        context.clip(to: clip)
        var transform = PixelTransform()
        if transformation == 1 {
            context.translateBy(x: 8, y: 1)
            context.rotate(by: 0.4)
            transform.translate(horizontal: 8, vertical: 1)
            transform.rotate(0.4)
        } else if transformation == 2 {
            context.scaleBy(x: 1.3, y: 0.7)
            transform.scale(horizontal: 1.3, vertical: 0.7)
        } else if transformation == 3 {
            context.translateBy(x: 27, y: 1)
            context.scaleBy(x: -1.2, y: 1.1)
            transform.translate(horizontal: 27, vertical: 1)
            transform.scale(horizontal: -1.2, vertical: 1.1)
        }
        let color = PixelColor(red: 90, green: 140, blue: 210, alpha: 128)
        let raster = PixelRasterPath(path, resolutionScale: transform.maximumScale)
        let clipping = PixelRasterPath(clip)
        let inverse = transform.inverse!

        // -- Act --
        context.stroke(path, with: color, lineWidth: 1.5)
        reference.paint(
            bounds: .init(minimumX: 0, minimumY: 0, maximumX: 32, maximumY: 24),
            color: color, opacity: 1,
            coverage: { point in
                clipping.contains(point) && raster.containsStroke(inverse.apply(point), radius: 0.75) ? 1 : 0
            })

        // -- Assert --
        #expect(actual.rgbaData == reference.rgbaData)
        #expect(actual.rgbaData.contains { $0 != 0 })
    }
}

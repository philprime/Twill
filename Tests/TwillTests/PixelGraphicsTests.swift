import Foundation
import Testing

@testable import Twill

@Suite("Pixel graphics paths and state")
@MainActor
struct PixelGraphicsTests {
    private let red = PixelColor(red: 255, green: 0, blue: 0)
    private let blue = PixelColor(red: 0, green: 0, blue: 255)

    @Test("Reusable paths use the style of each draw operation")
    func explicitStyles() throws {
        // -- Arrange --
        let rectangle = Path(PixelRect(x: 0, y: 0, width: 1, height: 1))

        // -- Act --
        let data = try render(width: 2, height: 1) { context in
            context.fill(rectangle, with: red)
            var translated = context
            translated.translateBy(x: 1, y: 0)
            translated.fill(rectangle, with: blue)
        }

        // -- Assert --
        #expect(data == Data([255, 0, 0, 255, 0, 0, 255, 255]))
    }

    @Test("Context copies share pixels while isolating opacity and transforms")
    func copiedState() throws {
        // -- Arrange --
        let pixel = Path(PixelRect(x: 0, y: 0, width: 1, height: 1))

        // -- Act --
        let data = try render(width: 2, height: 1) { context in
            var copy = context
            copy.translateBy(x: 1, y: 0)
            copy.opacity = 0.5
            copy.fill(pixel, with: red)
            context.fill(pixel, with: blue)
        }

        // -- Assert --
        #expect(data == Data([0, 0, 255, 255, 255, 0, 0, 128]))
    }

    @Test("Clipping affects only its context copy and is frozen in device coordinates")
    func clipping() throws {
        // -- Arrange --
        let pixel = Path(PixelRect(x: 0, y: 0, width: 1, height: 1))
        let row = Path(PixelRect(x: 0, y: 0, width: 3, height: 1))

        // -- Act --
        let data = try render(width: 3, height: 1) { context in
            var clipped = context
            clipped.translateBy(x: 1, y: 0)
            clipped.clip(to: pixel)
            clipped.translateBy(x: 1, y: 0)
            clipped.fill(row, with: red)
            clipped.translateBy(x: -2, y: 0)
            clipped.fill(row, with: red)
            context.fill(pixel, with: blue)
        }

        // -- Assert --
        #expect(data == Data([0, 0, 255, 255, 255, 0, 0, 255, 0, 0, 0, 0]))
    }

    @Test("Fill implicitly closes contours and nonzero winding can describe holes")
    func winding() throws {
        // -- Arrange --
        let path = Path { path in
            path.addRect(PixelRect(x: 0, y: 0, width: 3, height: 3))
            path.move(to: .init(x: 1, y: 1))
            path.addLine(to: .init(x: 1, y: 2))
            path.addLine(to: .init(x: 2, y: 2))
            path.addLine(to: .init(x: 2, y: 1))
        }

        // -- Act --
        let data = try render(width: 3, height: 3) { context in context.fill(path, with: red) }

        // -- Assert --
        #expect(data[3] == 255)
        #expect(data[4 * 4 + 3] == 0)
        #expect(data[4 * 8 + 3] == 255)
    }

    @Test("Move starts a distinct contour and a stroke does not implicitly close it")
    func openContours() throws {
        // -- Arrange --
        let path = Path { path in
            path.move(to: .init(x: 0.5, y: 0.5))
            path.addLine(to: .init(x: 4.5, y: 0.5))
            path.addLine(to: .init(x: 4.5, y: 4.5))
            path.move(to: .init(x: 0.5, y: 4.5))
            path.addLine(to: .init(x: 1.5, y: 4.5))
        }

        // -- Act --
        let data = try render(width: 5, height: 5) { context in
            context.stroke(path, with: red, lineWidth: 1)
        }

        // -- Assert --
        #expect(data[4 * 2 + 3] == 255)
        #expect(data[4 * 12 + 3] == 0)
        #expect(data[4 * 20 + 3] > 0)
    }

    @Test("A translucent polyline composites joins only once")
    func translucentJoins() throws {
        // -- Arrange --
        let path = Path { path in
            path.move(to: .init(x: 0.5, y: 1.5))
            path.addLine(to: .init(x: 1.5, y: 1.5))
            path.addLine(to: .init(x: 1.5, y: 0.5))
        }

        // -- Act --
        let data = try render(width: 3, height: 3) { context in
            context.stroke(path, with: .init(red: 255, green: 0, blue: 0, alpha: 128), lineWidth: 2)
        }

        // -- Assert --
        #expect(data[4 * 4 + 3] == 128)
    }

    @Test("Ellipse paths support fill and stroke with transparent interiors")
    func ellipses() throws {
        // -- Arrange --
        let ellipse = Path(ellipseIn: PixelRect(x: 0, y: 0, width: 5, height: 3))

        // -- Act --
        let filled = try render(width: 5, height: 3) { $0.fill(ellipse, with: red) }
        let stroked = try render(width: 5, height: 3) { $0.stroke(ellipse, with: red, lineWidth: 1) }

        // -- Assert --
        #expect(filled[4 * 7 + 3] == 255)
        #expect(stroked[4 * 7 + 3] == 0)
        #expect(stroked[4 * 5 + 3] > 0)
        #expect(filled.contains { $0 > 0 && $0 < 255 })
    }

    @Test("Scale and rotation compose in drawing order")
    func transforms() throws {
        // -- Arrange --
        let rectangle = Path(PixelRect(x: 0, y: 0, width: 1, height: 2))

        // -- Act --
        let data = try render(width: 4, height: 4) { context in
            var copy = context
            copy.translateBy(x: 4, y: 0)
            copy.rotate(by: .pi / 2)
            copy.scaleBy(x: 2, y: 1)
            copy.fill(rectangle, with: red)
        }

        // -- Assert --
        #expect(data[4 * 2 + 3] == 255)
        #expect(data[4 * 3 + 3] == 255)
        #expect(data[4 * 6 + 3] == 255)
        #expect(data[4 * 7 + 3] == 255)
        #expect(data[3] == 0)
        #expect(data[4 * 10 + 3] == 0)
    }

    @Test("Nonuniform scaling transforms stroke width as well as its centerline")
    func scaledStroke() throws {
        // -- Arrange --
        let line = Path { path in
            path.move(to: .init(x: 1, y: 0))
            path.addLine(to: .init(x: 1, y: 2))
        }

        // -- Act --
        let data = try render(width: 6, height: 4) { context in
            var scaled = context
            scaled.scaleBy(x: 2, y: 1)
            scaled.stroke(line, with: red, lineWidth: 1)
        }

        // -- Assert --
        #expect(data[4 * 6 + 3] == 0)
        #expect(data[4 * 7 + 3] == 255)
        #expect(data[4 * 8 + 3] == 255)
        #expect(data[4 * 9 + 3] == 0)
    }

    @Test("Explicit closure adds the closing stroke without mutating the original path")
    func closedStroke() throws {
        // -- Arrange --
        let open = Path { path in
            path.move(to: .init(x: 0.5, y: 0.5))
            path.addLine(to: .init(x: 2.5, y: 0.5))
            path.addLine(to: .init(x: 2.5, y: 2.5))
        }
        var closed = open
        closed.closeSubpath()

        // -- Act --
        let openData = try render(width: 3, height: 3) { $0.stroke(open, with: red) }
        let closedData = try render(width: 3, height: 3) { $0.stroke(closed, with: red) }

        // -- Assert --
        #expect(openData[4 * 4 + 3] == 0)
        #expect(closedData[4 * 4 + 3] > 0)
    }

    @Test("Intersecting clips and degenerate transforms draw no pixels outside their common area")
    func intersections() throws {
        // -- Arrange --
        let row = Path(PixelRect(x: 0, y: 0, width: 3, height: 1))

        // -- Act --
        let data = try render(width: 3, height: 1) { context in
            var clipped = context
            clipped.clip(to: Path(PixelRect(x: 0, y: 0, width: 2, height: 1)))
            clipped.clip(to: Path(PixelRect(x: 1, y: 0, width: 2, height: 1)))
            clipped.fill(row, with: red)
            var collapsed = context
            collapsed.scaleBy(x: 0, y: 1)
            collapsed.fill(row, with: blue)
            collapsed.stroke(row, with: blue)
        }

        // -- Assert --
        #expect(data == Data([0, 0, 0, 0, 255, 0, 0, 255, 0, 0, 0, 0]))
    }

    @Test("An ellipse retains its starting point for a following line")
    func ellipseContinuation() throws {
        // -- Arrange --
        let ellipse = Path(ellipseIn: PixelRect(x: 0, y: 0, width: 4, height: 4))
        var continued = ellipse
        continued.addLine(to: .init(x: 8, y: 2))

        // -- Act --
        let original = try render(width: 10, height: 6) { $0.stroke(ellipse, with: red) }
        let extended = try render(width: 10, height: 6) { $0.stroke(continued, with: red) }

        // -- Assert --
        #expect(original[4 * (2 * 10 + 6) + 3] == 0)
        #expect(extended[4 * (2 * 10 + 6) + 3] > 0)
    }

    @Test("Large finite ellipses can fill and clip a small canvas", arguments: [false, true], [1e40, 5e307])
    func largeEllipse(clipped: Bool, radius: Double) throws {
        // -- Arrange --
        let ellipse = Path(ellipseIn: PixelRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        let rectangle = Path(PixelRect(x: 0, y: 0, width: 3, height: 3))

        // -- Act --
        let data = try render(width: 3, height: 3) { context in
            if clipped {
                var copy = context
                copy.clip(to: ellipse)
                copy.fill(rectangle, with: red)
            } else {
                context.fill(ellipse, with: red)
            }
        }

        // -- Assert --
        #expect(data == Data(Array(repeating: [UInt8(255), 0, 0, 255], count: 9).flatMap { $0 }))
    }

    @Test("Large ellipse strokes and offscreen fills leave a small canvas untouched")
    func largeEllipseOutsideCanvas() throws {
        // -- Arrange --
        let enclosing = Path(ellipseIn: PixelRect(x: -1e40, y: -1e40, width: 2e40, height: 2e40))
        let offscreen = Path(ellipseIn: PixelRect(x: 1e40, y: 1e40, width: 2e40, height: 2e40))

        // -- Act --
        let data = try render(width: 3, height: 3) { context in
            context.stroke(enclosing, with: red)
            context.fill(offscreen, with: red)
        }

        // -- Assert --
        #expect(data == Data(repeating: 0, count: 36))
    }

    @Test("Paths remain independent values and empty paths and zero width draw nothing")
    func valuesAndEmptyPaths() throws {
        // -- Arrange --
        let original = Path()
        var copy = original
        copy.addRect(PixelRect(x: 0, y: 0, width: 2, height: 2))

        // -- Act --
        let data = try render(width: 2, height: 2) { context in
            context.fill(original, with: red)
            context.stroke(copy, with: red, lineWidth: 0)
        }

        // -- Assert --
        #expect(data == Data(repeating: 0, count: 16))
    }

    private func render(
        width: Int, height: Int, draw: @escaping @MainActor (PixelCanvas.Context) -> Void
    ) throws -> Data {
        let renderer = ViewRenderer.make(
            PixelCanvas(pixelsPerCell: .init(width: 1, height: 1)) { context, _ in draw(context) }
                .frame(width: width, height: height))
        return try #require(renderer.render(.now).grid?.images.first?.data)
    }
}

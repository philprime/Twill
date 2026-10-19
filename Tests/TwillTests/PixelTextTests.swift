import Foundation
import Testing
import TwillTextRendering

@testable import Twill

@Suite("Pixel canvas text")
@MainActor
struct PixelTextTests {
    #if TESTING
        @Test("Measurement uses backend metrics and forwards the requested text and font")
        func backendMeasurement() {
            // -- Arrange --
            let backend = RecordingTextRenderer()
            let context = PixelCanvas.Context(
                surface: PixelSurface(size: .init(width: 10, height: 10)), textRenderer: backend)
            let text = PixelText("Label", font: PixelFont(size: 13.5, weight: .bold))

            // -- Act --
            let metrics = context.measure(text)

            // -- Assert --
            #expect(metrics.width == 2)
            #expect(metrics.height == 2)
            #expect(metrics.firstBaseline == 1.5)
            #expect(backend.requests.count == 1)
            #expect(backend.requests.first?.text == "Label")
            #expect(backend.requests.first?.style == TextStyle(size: 13.5, weight: .bold))
        }

        @Test("Glyph coverage combines with text alpha and copied context opacity")
        func coverage() {
            // -- Arrange --
            let surface = PixelSurface(size: .init(width: 2, height: 2))
            let context = PixelCanvas.Context(surface: surface, textRenderer: RecordingTextRenderer())
            var faded = context
            faded.opacity = 0.5
            let text = PixelText("Label", color: .init(red: 200, green: 100, blue: 50, alpha: 128))

            // -- Act --
            faded.draw(text, at: .init(x: 0, y: 0), anchor: .topLeading)

            // -- Assert --
            #expect(surface.rgbaData == Data([200, 100, 50, 64, 200, 100, 50, 32, 0, 0, 0, 0, 200, 100, 50, 64]))
            #expect(context.opacity == 1)
        }

        @Test("Anchored text follows transforms and existing clips")
        func transformedClip() {
            // -- Arrange --
            let surface = PixelSurface(size: .init(width: 6, height: 4))
            var context = PixelCanvas.Context(surface: surface, textRenderer: RecordingTextRenderer())
            context.clip(to: Path(PixelRect(x: 2, y: 1, width: 1, height: 1)))
            context.translateBy(x: 2, y: 1)
            context.scaleBy(x: 2, y: 1)
            let text = PixelText("Label", color: .init(red: 255, green: 0, blue: 0))

            // -- Act --
            context.draw(text, at: .init(x: 1, y: 1))
            let bytes = surface.rgbaData

            // -- Assert --
            #expect(bytes[4 * (1 * 6 + 2)] == 255)
            #expect(bytes[4 * (1 * 6 + 2) + 3] == 255)
            #expect(bytes.enumerated().filter { $0.offset % 4 == 3 && $0.element != 0 }.count == 1)
        }

        @Test("Anchors use layout bounds rather than glyph bitmap bounds")
        func glyphOverhang() {
            // -- Arrange --
            let backend = RecordingTextRenderer()
            backend.result = TextLayout(
                width: 4, height: 4, firstBaseline: 3,
                bitmap: TextBitmap(width: 1, height: 1, originX: -1, originY: 1, coverage: [255]))
            let surface = PixelSurface(size: .init(width: 8, height: 8))
            let context = PixelCanvas.Context(surface: surface, textRenderer: backend)

            // -- Act --
            context.draw(PixelText("A"), at: .init(x: 4, y: 4))
            let bytes = surface.rgbaData

            // -- Assert --
            #expect(bytes[4 * (3 * 8 + 1) + 3] == 255)
            #expect(bytes.enumerated().filter { $0.offset % 4 == 3 && $0.element != 0 }.count == 1)
        }

        @Test(
            "Named and custom anchors align the label layout box",
            arguments: [
                (UnitPoint.topLeading, 6, 6), (UnitPoint.top, 5, 6), (UnitPoint.topTrailing, 4, 6),
                (UnitPoint.leading, 6, 5), (UnitPoint.center, 5, 5), (UnitPoint.trailing, 4, 5),
                (UnitPoint.bottomLeading, 6, 4), (UnitPoint.bottom, 5, 4), (UnitPoint.bottomTrailing, 4, 4),
                (UnitPoint(x: 1.5, y: -0.5), 3, 7),
            ])
        func anchors(anchor: UnitPoint, column: Int, row: Int) {
            // -- Arrange --
            let backend = RecordingTextRenderer()
            let surface = PixelSurface(size: .init(width: 10, height: 10))
            let context = PixelCanvas.Context(surface: surface, textRenderer: backend)
            var expected = Data(repeating: 0, count: 400)
            for (offsetX, offsetY, alpha) in [(0, 0, UInt8(255)), (1, 0, UInt8(128)), (1, 1, UInt8(255))] {
                let offset = 4 * ((row + offsetY) * 10 + column + offsetX)
                expected.replaceSubrange(offset..<(offset + 4), with: [255, 255, 255, alpha])
            }

            // -- Act --
            context.draw(PixelText("A"), at: .init(x: 6, y: 6), anchor: anchor)

            // -- Assert --
            #expect(surface.rgbaData == expected)
        }

        @Test("Fractional anchors retain subpixel placement")
        func fractionalAnchor() {
            // -- Arrange --
            let backend = RecordingTextRenderer()
            backend.result = TextLayout(
                width: 2, height: 2, firstBaseline: 1.5,
                bitmap: TextBitmap(width: 1, height: 1, coverage: [255]))
            let surface = PixelSurface(size: .init(width: 3, height: 3))
            let context = PixelCanvas.Context(surface: surface, textRenderer: backend)

            // -- Act --
            context.draw(PixelText("A"), at: .init(x: 1, y: 2), anchor: .init(x: 0.25, y: 0.75))
            let bytes = surface.rgbaData

            // -- Assert --
            #expect([bytes[3], bytes[7], bytes[15], bytes[19]] == [64, 64, 64, 64])
            #expect(bytes.enumerated().filter { $0.offset % 4 == 3 && $0.element != 0 }.count == 4)
        }

        @Test("Zero-scale text draws no pixels without changing measurement")
        func zeroScale() {
            // -- Arrange --
            let backend = RecordingTextRenderer()
            let surface = PixelSurface(size: .init(width: 4, height: 4))
            var context = PixelCanvas.Context(surface: surface, textRenderer: backend)
            context.scaleBy(x: 0, y: 1)
            let text = PixelText("A")

            // -- Act --
            let metrics = context.measure(text)
            context.draw(text, at: .init(x: 2, y: 2))

            // -- Assert --
            #expect(metrics.width == 2)
            #expect(metrics.height == 2)
            #expect(surface.rgbaData == Data(repeating: 0, count: 64))
        }

        private final class RecordingTextRenderer: TextRenderer {
            var requests: [(text: String, style: TextStyle)] = []
            var result = TextLayout(
                width: 2, height: 2, firstBaseline: 1.5,
                bitmap: TextBitmap(width: 2, height: 2, coverage: [255, 128, 0, 255]))

            func layout(_ text: String, style: TextStyle) -> TextLayout {
                requests.append((text, style))
                return result
            }
        }
    #endif

    @Test("Text measurement uses consistent monospace advances and line metrics")
    func measurement() {
        // -- Arrange --
        let context = PixelCanvas.Context(surface: PixelSurface(size: .init(width: 32, height: 32)))
        let font = PixelFont(size: 13.5)

        // -- Act --
        let single = context.measure(PixelText("A", font: font))
        let pair = context.measure(PixelText("AA", font: font))

        // -- Assert --
        #expect(single.width > 0)
        #expect(pair.width == single.width * 2)
        #expect(pair.height == single.height)
        #expect(pair.firstBaseline == single.firstBaseline)
        #expect(single.firstBaseline > 0 && single.firstBaseline <= single.height)
    }

    @Test("Top-anchored real glyphs move by the requested pixel offset")
    func topAnchor() {
        // -- Arrange --
        let first = PixelSurface(size: .init(width: 32, height: 32))
        let second = PixelSurface(size: .init(width: 32, height: 32))
        let text = PixelText("A", font: PixelFont(size: 12), color: .init(red: 255, green: 0, blue: 0))

        // -- Act --
        PixelCanvas.Context(surface: first).draw(text, at: .init(x: 12, y: 2), anchor: .top)
        PixelCanvas.Context(surface: second).draw(text, at: .init(x: 15, y: 4), anchor: .top)
        let bytes = first.rgbaData
        var shifted = Data(repeating: 0, count: 32 * 32 * 4)
        for row in 0..<30 {
            for column in 0..<29 {
                let source = 4 * (row * 32 + column)
                let destination = 4 * ((row + 2) * 32 + column + 3)
                shifted.replaceSubrange(destination..<(destination + 4), with: bytes[source..<(source + 4)])
            }
        }

        // -- Assert --
        #expect(bytes.contains { $0 > 0 })
        #expect(second.rgbaData == shifted)
    }

    @Test("Empty labels neither reserve a line nor draw pixels")
    func emptyText() {
        // -- Arrange --
        let surface = PixelSurface(size: .init(width: 4, height: 4))
        let context = PixelCanvas.Context(surface: surface)
        let text = PixelText("")

        // -- Act --
        let metrics = context.measure(text)
        context.draw(text, at: .init(x: 2, y: 2))

        // -- Assert --
        #expect(metrics.width == 0)
        #expect(metrics.height == 0)
        #expect(metrics.firstBaseline == 0)
        #expect(surface.rgbaData == Data(repeating: 0, count: 64))
    }

    @Test("The public text API participates in canvas presentation")
    func presentation() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            PixelCanvas(pixelsPerCell: .init(width: 10, height: 10)) { context, _ in
                context.draw(
                    PixelText("A", font: PixelFont(size: 5)),
                    at: .init(x: 0, y: 0), anchor: .topLeading)
            }.frame(width: 1, height: 1))

        // -- Act --
        let frame = renderer.render(.now)
        let image = try #require(frame.grid?.images.first)

        // -- Assert --
        #expect(image.format == .rgba(width: 10, height: 10))
        #expect(image.data.contains { $0 != 0 })
        #expect(frame.nextUpdate == nil)
    }
}

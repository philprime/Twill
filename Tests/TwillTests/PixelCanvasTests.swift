import Foundation
import Testing

@testable import Twill

@Suite("Pixel canvas")
@MainActor
struct PixelCanvasTests {
    @Test("RGBA drawing reaches the host with pixel dimensions and cell placement")
    func presentation() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            PixelCanvas(pixelsPerCell: .init(width: 2, height: 3)) { context, size in
                #expect(size == PixelSize(width: 4, height: 3))
                context.fill(
                    Path(PixelRect(x: 0, y: 0, width: 4, height: 3)),
                    with: .init(red: 255, green: 0, blue: 0))
            }.frame(width: 2, height: 1).padding(1))

        // -- Act --
        let frame = renderer.render(.now).grid
        let image = try #require(frame?.images.first)
        let encoded = KittyImageEncoder.display(image, id: 7)

        // -- Assert --
        #expect(image.bounds == CellRect(column: 1, row: 1, width: 2, height: 1))
        #expect(image.data == Data(Array(repeating: [UInt8(255), 0, 0, 255], count: 12).flatMap { $0 }))
        #expect(encoded.contains("f=32,s=4,v=3,"))
        #expect(encoded.contains("c=2,r=1,"))
        #expect(!encoded.contains("o=z"))
    }

    @Test("Filled paths clip and composite straight alpha")
    func blending() throws {
        // -- Arrange --
        let row = Path(PixelRect(x: 0, y: 0, width: 2, height: 1))
        let pixel = Path(PixelRect(x: 0, y: 0, width: 1, height: 1))

        // -- Act --
        let data = try render(width: 2, height: 1) { context in
            context.fill(row, with: .init(red: 0, green: 0, blue: 255))
            context.fill(pixel, with: .init(red: 255, green: 0, blue: 0, alpha: 128))
            context.fill(
                Path(PixelRect(x: -1, y: 0, width: 1, height: 1)),
                with: .init(red: 0, green: 255, blue: 0))
            context.fill(
                Path(PixelRect(x: 2, y: 0, width: 1, height: 1)),
                with: .init(red: 0, green: 255, blue: 0))
        }

        // -- Assert --
        #expect(data == Data([128, 0, 127, 255, 0, 0, 255, 255]))
    }

    @Test("Transparent fills preserve destination pixels and retain straight RGB")
    func transparency() throws {
        // -- Arrange --
        let pixel = Path(PixelRect(x: 0, y: 0, width: 1, height: 1))

        // -- Act --
        let data = try render(width: 1, height: 1) { context in
            context.fill(pixel, with: .init(red: 200, green: 100, blue: 50, alpha: 128))
            context.fill(pixel, with: .clear)
        }

        // -- Assert --
        #expect(data == Data([200, 100, 50, 128]))
    }

    @Test("Lines and ellipses rasterize into clipped antialiased pixels")
    func shapes() throws {
        // -- Arrange --
        let red = PixelColor(red: 255, green: 0, blue: 0)
        let line = Path { path in
            path.move(to: .init(x: -10, y: 2.5))
            path.addLine(to: .init(x: 10, y: 2.5))
        }

        // -- Act --
        let data = try render(width: 5, height: 5) { context in
            context.stroke(line, with: red)
            context.fill(Path(ellipseIn: PixelRect(x: 1.5, y: 1.5, width: 2, height: 2)), with: red)
        }

        // -- Assert --
        #expect(data[4 * (2 * 5 + 2) + 3] == 255)
        #expect(data[4 * (2 * 5) + 3] == 255)
        #expect(data[3] == 0)
        #expect(data.contains { $0 > 0 && $0 < 255 })
    }

    @Test("Rectangles clip to the bitmap and preserve pixels outside the rectangle")
    func rectangles() throws {
        // -- Arrange --
        let path = Path(PixelRect(x: -1, y: 0, width: 3, height: 1))

        // -- Act --
        let data = try render(width: 3, height: 2) { context in
            context.fill(path, with: .init(red: 0, green: 255, blue: 0))
        }

        // -- Assert --
        #expect(
            data
                == Data([
                    0, 255, 0, 255, 0, 255, 0, 255, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                ]))
    }

    @Test("Pixel changes redraw while identical frames remain idle and removal deletes the image")
    func updates() throws {
        // -- Arrange --
        let model = PixelModel()
        let renderer = ViewRenderer.make(
            PixelCanvas { context, size in
                context.fill(
                    Path(PixelRect(x: 0, y: 0, width: Double(size.width), height: Double(size.height))),
                    with: model.color)
            }.frame(width: 1, height: 1))
        let output = RecordingTerminalOutput()
        let presenter = TerminalPresenter(output: output, mode: .fullscreen)
        let first = renderer.render(.now)
        try presenter.present(FrameSnapshot(grid: first.grid, caret: nil))
        let writes = output.writes.count

        // -- Act --
        try presenter.present(FrameSnapshot(grid: renderer.render(.now).grid, caret: nil))
        let unchangedWrites = output.writes.count
        model.color = PixelColor(red: 0, green: 0, blue: 255)
        try presenter.present(FrameSnapshot(grid: renderer.render(.now).grid, caret: nil))
        let changedWrites = output.writes.count
        try presenter.present(FrameSnapshot(grid: nil, caret: nil))

        // -- Assert --
        #expect(unchangedWrites == writes)
        #expect(changedWrites == writes + 1)
        #expect(output.writes.last?.contains("a=d,d=I") == true)
        #expect(output.writes.last?.contains("a=T") == false)
        #expect(first.nextUpdate == nil)
    }

    @Test("Raw pixel payloads are chunked without losing bytes")
    func chunks() {
        // -- Arrange --
        let bytes = Data((0..<4800).map { UInt8($0 % 256) })
        let image = ImagePlacement(
            data: bytes, bounds: CellRect(column: 0, row: 0, width: 20, height: 10),
            format: .rgba(width: 40, height: 30))

        // -- Act --
        let encoded = KittyImageEncoder.display(image, id: 9)
        let payloads = encoded.components(separatedBy: "\u{1B}_G").dropFirst().compactMap {
            $0.components(separatedBy: ";").last?.components(separatedBy: "\u{1B}\\").first
        }

        // -- Assert --
        #expect(encoded.contains("f=32,s=40,v=30,"))
        #expect(payloads.count == 2)
        #expect(payloads.allSatisfy { $0.count <= 4096 })
        #expect(Data(base64Encoded: payloads.joined()) == bytes)
    }

    private final class PixelModel {
        var color = PixelColor(red: 255, green: 0, blue: 0)
    }

    @Test("Pixel canvas shares remaining stack space with intrinsic siblings")
    func stackLayout() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(spacing: 0) {
                PixelCanvas { context, size in
                    context.fill(
                        Path(PixelRect(x: 0, y: 0, width: Double(size.width), height: Double(size.height))),
                        with: .init(red: 255, green: 0, blue: 0))
                }
                Text("Caption")
            }.frame(width: 10, height: 4))

        // -- Act --
        let frame = renderer.render(.now).grid
        let image = try #require(frame?.images.first)

        // -- Assert --
        #expect(image.bounds == CellRect(column: 0, row: 0, width: 10, height: 3))
        #expect(image.format == .rgba(width: 80, height: 48))
        #expect(frame?.snapshotText.contains("Caption") == true)
    }

    @Test("Constrained geometry determines resolution and empty regions skip drawing")
    func geometry() {
        // -- Arrange --
        var sizes: [PixelSize] = []
        let renderer = ViewRenderer.make(PixelCanvas { _, size in sizes.append(size) })

        // -- Act --
        let frame = renderer.render(.now, proposal: .init(width: 3, height: 2)).grid
        let empty = renderer.render(.now, proposal: .init(width: 0, height: 0)).grid

        // -- Assert --
        #expect(sizes == [.init(width: 24, height: 32)])
        #expect(frame?.images.count == 1)
        #expect(empty?.images.isEmpty != false)
        #expect(renderer.render(.now, proposal: .init(width: 1, height: 1)).nextUpdate == nil)
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

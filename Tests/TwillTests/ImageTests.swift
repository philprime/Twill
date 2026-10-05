import Foundation
import Testing

@testable import Twill

@Suite("Terminal images")
@MainActor
struct ImageTests {
    private let png = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!

    @Test("Images participate in layout and retain their translated placement")
    func placement() throws {
        // -- Arrange --
        let image = ImageView(try Image(pngData: png), width: 4, height: 2)
        let renderer = ViewRenderer.make(image.padding(1))

        // -- Act --
        let frame = renderer.render(.now).grid

        // -- Assert --
        #expect(frame?.size == CellSize(width: 6, height: 4))
        #expect(frame?.images.count == 1)
        #expect(frame?.images.first?.bounds == CellRect(column: 1, row: 1, width: 4, height: 2))
    }

    @Test("Image uploads are chunked and preserve the cursor")
    func chunking() {
        // -- Arrange --
        let placement = ImagePlacement(
            data: Data(repeating: 255, count: 4000), bounds: CellRect(column: 2, row: 3, width: 4, height: 5))

        // -- Act --
        let encoded = KittyImageEncoder.display(placement, id: 7)

        // -- Assert --
        #expect(encoded.hasPrefix("\r\u{1B}[3B\u{1B}[2C\u{1B}_Ga=T,t=d,f=100,q=2,C=1,i=7,c=4,r=5,m=1;"))
        #expect(encoded.contains("\u{1B}\\\u{1B}_Gm=0;"))
        #expect(encoded.hasSuffix("\u{1B}\\\r\u{1B}[3A"))
        let payloads = encoded.components(separatedBy: "\u{1B}_G").dropFirst().compactMap {
            $0.components(separatedBy: ";").last?.components(separatedBy: "\u{1B}\\").first
        }
        #expect(payloads.allSatisfy { $0.count <= 4096 })
        #expect(Data(base64Encoded: payloads.joined()) == placement.data)
    }

    @Test("Unchanged images are idle and removal frees only owned image IDs")
    func lifecycle() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let presenter = TerminalPresenter(output: output, mode: .fullscreen)
        let renderer = ViewRenderer.make(ImageView(try Image(pngData: png), width: 4, height: 2))
        let frame = FrameSnapshot(grid: renderer.render(.now).grid, caret: nil)
        try presenter.present(frame)
        let count = output.writes.count

        // -- Act --
        try presenter.present(frame)
        #expect(output.writes.count == count)
        presenter.stop()

        // -- Assert --
        #expect(output.writes.first?.contains("a=T,t=d,f=100") == true)
        #expect(output.writes.last?.contains("a=d,d=I") == true)
        #expect(output.writes.last?.contains("d=A") == false)
    }

    @Test("Later cell drawing hides intersecting images instead of covering a modal with graphics")
    func occlusion() {
        // -- Arrange --
        var context = DrawingContext(size: CellSize(width: 8, height: 4))
        context.drawImage(png, size: CellSize(width: 4, height: 2))

        // -- Act --
        context.draw("X", width: 1, column: 1, row: 1)

        // -- Assert --
        #expect(context.grid.images.isEmpty)
    }

    @Test("A failed image upload leaves IDs available for shutdown cleanup")
    func failedUploadCleanup() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let presenter = TerminalPresenter(output: output, mode: .fullscreen)
        let renderer = ViewRenderer.make(ImageView(try Image(pngData: png), width: 4, height: 2))
        let frame = FrameSnapshot(grid: renderer.render(.now).grid, caret: nil)
        output.nextFailure = ImageWriteFailure.failed

        // -- Act --
        #expect(throws: ImageWriteFailure.self) { try presenter.present(frame) }
        presenter.stop()

        // -- Assert --
        #expect(output.writes.count == 1)
        #expect(output.writes.first?.contains("a=d,d=I") == true)
    }

    @Test("Partially clipped images are omitted, while a constrained layout scales its placement")
    func clipping() throws {
        // -- Arrange --
        var context = DrawingContext(size: CellSize(width: 4, height: 2))
        let renderer = ViewRenderer.make(ImageView(try Image(pngData: png), width: 8, height: 4))

        // -- Act --
        context.withRegion(CellRect(column: -1, row: 0, width: 4, height: 2)) {
            $0.drawImage(png, size: CellSize(width: 4, height: 2))
        }
        let frame = renderer.render(.now, proposal: ProposedCellSize(width: 4, height: 2)).grid

        // -- Assert --
        #expect(context.grid.images.isEmpty)
        #expect(frame?.images.first?.bounds == CellRect(column: 0, row: 0, width: 4, height: 2))
    }

    private enum ImageWriteFailure: Error { case failed }

    @Test("Invalid PNG data is rejected")
    func invalidInput() {
        // -- Arrange --
        let invalid = Data("not a PNG".utf8)

        // -- Act --
        // -- Assert --
        #expect(throws: Image.InvalidImage.self) { try Image(pngData: invalid) }
    }
}

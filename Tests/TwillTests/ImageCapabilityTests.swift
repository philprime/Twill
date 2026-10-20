import Foundation
import Testing

@testable import Twill

@Suite("Capability-aware image layout")
@MainActor
struct ImageCapabilityTests {
    private func image(width: UInt32 = 100, height: UInt32 = 100) throws -> Image {
        var bytes: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82]
        for value in [width, height] {
            bytes += [
                UInt8((value >> 24) & 255), UInt8((value >> 16) & 255), UInt8((value >> 8) & 255), UInt8(value & 255),
            ]
        }
        return try Image(pngData: Data(bytes))
    }

    @Test("Unsupported snapshots mount only caller fallback content")
    func unsupported() throws {
        // -- Arrange --
        var actions = 0
        let renderer = ViewRenderer.make(
            ImageView(try image(), width: 10, height: 10) {
                Button("Unsupported") { actions += 1 }
            }, terminalCapabilities: TerminalCapabilities())

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.enter)

        // -- Assert --
        #expect(grid.snapshotText == "Unsupported" && grid.images.isEmpty)
        #expect(actions == 1)
    }

    @Test("Aspect fit centers physical image proportions in the requested cell rectangle")
    func aspectFit() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            ImageView(try image(), width: 10, height: 10) { Text("Unsupported") },
            terminalCapabilities: TerminalCapabilities(imageProtocol: .kitty))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)
        let resized = try #require(renderer.drawFrame(proposal: .init(width: 4, height: 4)))

        // -- Assert --
        #expect(grid.size == CellSize(width: 10, height: 10))
        #expect(grid.images.first?.bounds == CellRect(column: 0, row: 2, width: 10, height: 5))
        #expect(resized.images.first?.bounds == CellRect(column: 0, row: 1, width: 4, height: 2))
    }

    @Test("Wide and tall pixels respect explicit cell aspect assumptions")
    func pixelAndCellAspects() throws {
        // -- Arrange --
        let wide = ViewRenderer.make(
            ImageView(try image(width: 200, height: 100), width: 10, height: 10) { EmptyView() },
            terminalCapabilities: TerminalCapabilities(imageProtocol: .kitty))
        let tall = ViewRenderer.make(
            ImageView(try image(width: 100, height: 200), width: 10, height: 10) { EmptyView() },
            terminalCapabilities: TerminalCapabilities(imageProtocol: .kitty))
        let squareCells = ViewRenderer.make(
            ImageView(try image(), width: 10, height: 10) { EmptyView() },
            terminalCapabilities: TerminalCapabilities(imageProtocol: .kitty, cellHeightToWidth: 1))

        // -- Act --
        let wideGrid = try #require(wide.render(.now).grid)
        let tallGrid = try #require(tall.render(.now).grid)
        let squareGrid = try #require(squareCells.render(.now).grid)

        // -- Assert --
        #expect(wideGrid.images.first?.bounds == CellRect(column: 0, row: 4, width: 10, height: 2))
        #expect(tallGrid.images.first?.bounds == CellRect(column: 0, row: 0, width: 10, height: 10))
        #expect(squareGrid.images.first?.bounds == CellRect(column: 0, row: 0, width: 10, height: 10))
    }

    @Test("Stretch remains explicit and zero rectangles produce no placement")
    func stretchAndZero() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            ImageView(try image(), width: 10, height: 10, contentMode: .stretch) { EmptyView() },
            terminalCapabilities: TerminalCapabilities(imageProtocol: .kitty))

        // -- Act --
        let stretched = try #require(renderer.render(.now).grid)
        let zero = try #require(renderer.drawFrame(proposal: .init(width: 0, height: 0)))

        // -- Assert --
        #expect(stretched.images.first?.bounds == CellRect(column: 0, row: 0, width: 10, height: 10))
        #expect(zero.images.isEmpty && zero.size == .zero)
    }

    @Test("Partial viewport clipping omits placements without rescaling and resize reveals the full image")
    func clippingAndResize() throws {
        // -- Arrange --
        let value = try image()
        let renderer = ViewRenderer.make(
            ScrollView {
                VStack(spacing: 0) {
                    Text("Header")
                    ImageView(value, width: 8, height: 4) { EmptyView() }
                    Text("Footer")
                }
            }, terminalCapabilities: TerminalCapabilities(imageProtocol: .kitty))

        // -- Act --
        let clipped = try #require(renderer.render(.now, proposal: .init(width: 8, height: 3)).grid)
        let revealed = try #require(renderer.drawFrame(proposal: .init(width: 8, height: 5)))

        // -- Assert --
        #expect(clipped.images.isEmpty)
        #expect(revealed.images.first?.bounds == CellRect(column: 0, row: 1, width: 8, height: 4))
    }

    private struct Counted: View {
        let image: Image
        let evaluated: @MainActor () -> Void
        var body: some View {
            evaluated()
            return ImageView(image, width: 10, height: 10) { Text("Unsupported") }
        }
    }

    @Test("Aspect-fit resize reuses mounted descriptions")
    func cachedResize() throws {
        // -- Arrange --
        var evaluations = 0
        let renderer = ViewRenderer.make(
            Counted(image: try image(), evaluated: { evaluations += 1 }),
            terminalCapabilities: TerminalCapabilities(imageProtocol: .kitty))
        _ = renderer.render(.now)

        // -- Act --
        let resized = try #require(renderer.drawFrame(proposal: .init(width: 4, height: 4)))

        // -- Assert --
        #expect(evaluations == 1)
        #expect(resized.images.first?.bounds == CellRect(column: 0, row: 1, width: 4, height: 2))
    }

    @Test("Environment detection is an injectable hint snapshot")
    func environmentHints() {
        // -- Arrange --
        let supported = [["TERM_PROGRAM": "ghostty"], ["TERM": "xterm-kitty"], ["TERM": "xterm-ghostty"]]

        // -- Act --
        let protocols = supported.map { TerminalCapabilities.detect(environment: $0).imageProtocol }
        let unknown = TerminalCapabilities.detect(environment: ["TERM": "xterm-256color"])

        // -- Assert --
        #expect(protocols.allSatisfy { $0 == .kitty })
        #expect(unknown.imageProtocol == .none)
    }
}

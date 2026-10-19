import Foundation
import Testing

@testable import TwillTextRendering

@Suite("HarfBuzz text rendering")
@MainActor
struct HarfBuzzTextRendererTests {
    @Test("OpenType advances and baseline come from the loaded font")
    func metrics() throws {
        // -- Arrange --
        let renderer = try nativeRenderer()

        // -- Act --
        let layout = renderer.layout("AA", style: TextStyle(size: 10, weight: .regular))

        // -- Assert --
        #expect(layout.width == 12)
        #expect(layout.height == 12)
        #expect(layout.firstBaseline == 8)
        #expect(layout.bitmap.coverage.contains { $0 > 0 })
    }

    @Test("HarfBuzz ligatures affect both measurement and rasterization")
    func ligature() throws {
        // -- Arrange --
        let renderer = try nativeRenderer()

        // -- Act --
        let layout = renderer.layout("fi", style: TextStyle(size: 10, weight: .regular))

        // -- Assert --
        #expect(layout.width == 9)
        #expect(layout.bitmap.width == 8)
        #expect(layout.bitmap.height == 7)
        #expect(layout.bitmap.originX == 0)
        #expect(layout.bitmap.originY == 1)
        #expect(layout.bitmap.coverage == Array(repeating: 255, count: 56))
    }

    @Test("Fractional sizes produce antialiased glyph-specific masks")
    func glyphMasks() throws {
        // -- Arrange --
        let renderer = try nativeRenderer()
        let style = TextStyle(size: 10.5, weight: .regular)

        // -- Act --
        let triangle = renderer.layout("A", style: style)
        let rectangle = renderer.layout("B", style: style)

        // -- Assert --
        #expect(triangle.width == 6.296875)
        #expect(triangle.bitmap.coverage.contains { $0 > 0 && $0 < 255 })
        #expect(triangle.bitmap.coverage != rectangle.bitmap.coverage)
    }

    @Test("Whitespace advances do not invent ink and controls stay on one line")
    func whitespace() throws {
        // -- Arrange --
        let renderer = try nativeRenderer()
        let style = TextStyle(size: 10, weight: .regular)

        // -- Act --
        let plain = renderer.layout("A", style: style)
        let trailing = renderer.layout("A ", style: style)
        let blank = renderer.layout("  ", style: style)
        let controls = renderer.layout("A\nB\t", style: style)

        // -- Assert --
        #expect(trailing.width == 12)
        #expect(plain.bitmap.coverage == trailing.bitmap.coverage)
        #expect(blank.width == 12)
        #expect(blank.bitmap.coverage.isEmpty)
        #expect(controls.width == 24)
        #expect(controls.height == plain.height)
    }

    @Test("Shaping controls remain available to HarfBuzz rather than becoming spaces")
    func shapingControls() throws {
        // -- Arrange --
        let renderer = try nativeRenderer()
        let style = TextStyle(size: 10, weight: .regular)

        // -- Act --
        let joined = renderer.layout("f\u{200D}i", style: style)
        let plain = renderer.layout("fi", style: style)

        // -- Assert --
        #expect(joined.width == plain.width)
        #expect(joined.bitmap.coverage == plain.bitmap.coverage)
    }

    @Test("Descenders and left overhang remain separate from layout bounds")
    func overhang() throws {
        // -- Arrange --
        let renderer = try nativeRenderer()

        // -- Act --
        let layout = renderer.layout("f", style: TextStyle(size: 20, weight: .regular))

        // -- Assert --
        #expect(layout.width == 12)
        #expect(layout.firstBaseline == 16)
        #expect(layout.bitmap.originX == -1)
        #expect(layout.bitmap.originY == 2)
        #expect(layout.bitmap.width == 6)
        #expect(layout.bitmap.height == 18)
    }

    @Test("Changing font size cannot mutate previously returned or cached masks")
    func independentLayouts() throws {
        // -- Arrange --
        let renderer = try nativeRenderer()
        let small = TextStyle(size: 10, weight: .regular)

        // -- Act --
        let first = renderer.layout("A", style: small)
        let large = renderer.layout("A", style: TextStyle(size: 20, weight: .bold))
        let repeated = renderer.layout("A", style: small)

        // -- Assert --
        #expect(first.width == 6)
        #expect(large.width == 12)
        #expect(first.bitmap.coverage == repeated.bitmap.coverage)
        #expect(first.bitmap.coverage != large.bitmap.coverage)
    }

    @Test("Missing fonts use readable basic-Latin bitmaps and replace unsupported characters")
    func fallback() {
        // -- Arrange --
        let renderer = HarfBuzzTextRenderer(font: nil)
        let style = TextStyle(size: 8, weight: .regular)

        // -- Act --
        let latin = renderer.layout("AB", style: style)
        let missing = renderer.layout("🌍", style: style)
        let replacement = renderer.layout("?", style: style)
        let blank = renderer.layout(" ", style: style)

        // -- Assert --
        #expect(latin.width == 16)
        #expect(latin.height == 8)
        #expect(latin.firstBaseline == 7)
        #expect(latin.bitmap.coverage.contains(255))
        #expect(missing.bitmap.coverage == replacement.bitmap.coverage)
        #expect(blank.width == 8)
        #expect(blank.bitmap.coverage.isEmpty)
    }

    @Test("Bold changes glyph coverage without changing monospace advances")
    func bold() throws {
        // -- Arrange --
        let renderer = try nativeRenderer()

        // -- Act --
        let regular = renderer.layout("A", style: TextStyle(size: 20, weight: .regular))
        let bold = renderer.layout("A", style: TextStyle(size: 20, weight: .bold))

        // -- Assert --
        #expect(regular.width == bold.width)
        #expect(bold.bitmap.coverage.reduce(0) { $0 + Int($1) } > regular.bitmap.coverage.reduce(0) { $0 + Int($1) })
    }

    @Test("An unreadable system font uses the basic-Latin fallback")
    func invalidFont() {
        // -- Arrange --
        let renderer = HarfBuzzTextRenderer(font: FontLocation(path: "/nonexistent/twill-font.ttf"))

        // -- Act --
        let layout = renderer.layout("A", style: TextStyle(size: 8, weight: .regular))

        // -- Assert --
        #expect(layout.width == 8)
        #expect(layout.firstBaseline == 7)
        #expect(layout.bitmap.coverage.contains(255))
    }

    @Test("Directory discovery prefers a regular monospace font over bold files")
    func directoryDiscovery() throws {
        // -- Arrange --
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try #require(Bundle.module.url(forResource: "TwillTest", withExtension: "ttf"))
        let regular = directory.appendingPathComponent("DejaVuSansMono.ttf")
        try FileManager.default.copyItem(at: fixture, to: regular)
        try FileManager.default.copyItem(at: fixture, to: directory.appendingPathComponent("DejaVuSansMono-Bold.ttf"))

        // -- Act --
        let font = SystemFontLocator.locate(in: [directory])
        let renderer = HarfBuzzTextRenderer(font: font)
        let layout = renderer.layout("A", style: TextStyle(size: 10, weight: .regular))

        // -- Assert --
        let path = try #require(font?.path)
        let selected = try FileManager.default.attributesOfItem(atPath: path)
        let expected = try FileManager.default.attributesOfItem(atPath: regular.path)
        #expect(
            try #require(selected[.systemFileNumber] as? NSNumber) == #require(expected[.systemFileNumber] as? NSNumber)
        )
        #expect(layout.width == 6)
        #expect(layout.firstBaseline == 8)
    }

    #if canImport(CoreText)
        @Test("macOS resolves its system monospace font to usable OpenType outlines")
        func macOSSystemFont() throws {
            // -- Arrange --
            let location = try #require(SystemFontLocator.locate())
            let font = try #require(HarfBuzzFont(location: location))

            // -- Act --
            let layout = try #require(font.layout("Hello", style: TextStyle(size: 16, weight: .regular)))

            // -- Assert --
            #expect(layout.width > 0)
            #expect(layout.bitmap.coverage.contains { $0 > 0 && $0 < 255 })
        }
    #endif

    @Test("Empty labels reserve neither layout space nor bitmap storage")
    func empty() throws {
        // -- Arrange --
        let renderer = try nativeRenderer()

        // -- Act --
        let layout = renderer.layout("", style: TextStyle(size: 12, weight: .regular))

        // -- Assert --
        #expect(layout.width == 0)
        #expect(layout.height == 0)
        #expect(layout.firstBaseline == 0)
        #expect(layout.bitmap.coverage.isEmpty)
    }

    @Test("Native font resources can be released while returned coverage remains usable")
    func lifetime() throws {
        // -- Arrange --
        var coverages: [[UInt8]] = []

        // -- Act --
        for _ in 0..<20 {
            let renderer = try nativeRenderer()
            coverages.append(renderer.layout("B", style: TextStyle(size: 10, weight: .regular)).bitmap.coverage)
        }

        // -- Assert --
        #expect(coverages.allSatisfy { $0 == Array(repeating: 255, count: 35) })
    }

    private func nativeRenderer() throws -> HarfBuzzTextRenderer {
        let file = try #require(Bundle.module.url(forResource: "TwillTest", withExtension: "ttf"))
        return HarfBuzzTextRenderer(font: FontLocation(path: file.path))
    }
}

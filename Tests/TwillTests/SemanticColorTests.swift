import Testing

@testable import Twill

@Suite("Semantic colors and theme boundaries")
@MainActor
struct SemanticColorTests {
    @Test("Semantic styles resolve roles while concrete colors remain explicit")
    func roles() throws {
        // -- Arrange --
        let theme = Theme(
            foreground: .white, background: .black, accent: .cyan, muted: .brightBlack, validation: .yellow)
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("F").foregroundStyle(.foreground)
                Text("B").backgroundStyle(.background)
                Text("A").foregroundStyle(.accent)
                Text("M").foregroundStyle(.muted)
                Text("V").foregroundStyle(.validation)
                Text("C").foregroundStyle(Color.blue)
            }.theme(theme))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.snapshotText == "FBAMVC")
        #expect(grid.foreground(column: 0, row: 0) == .white)
        #expect(grid.background(column: 1, row: 0) == .black)
        #expect(grid.foreground(column: 2, row: 0) == .cyan)
        #expect(grid.foreground(column: 3, row: 0) == .brightBlack)
        #expect(grid.foreground(column: 4, row: 0) == .yellow)
        #expect(grid.foreground(column: 5, row: 0) == .blue)
    }

    @Test("Nested themes re-resolve inherited semantic declarations without affecting siblings")
    func nestedThemes() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                Text("B").theme(Theme(accent: .green))
                Text("C").foregroundStyle(Color.blue)
            }.foregroundStyle(.accent).theme(Theme(accent: .red)))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .red)
        #expect(grid.foreground(column: 1, row: 0) == .green)
        #expect(grid.foreground(column: 2, row: 0) == .blue)
    }

    @Test("Terminal-default roles clear inherited colors and background paint")
    func terminalDefaults() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Text("AB").foregroundStyle(.foreground).backgroundStyle(.background)
                Text("C")
            }.foregroundStyle(Color.red).backgroundStyle(Color.blue).theme(Theme()))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == nil)
        #expect(grid.background(column: 0, row: 0) == nil)
        #expect(grid.background(column: 1, row: 0) == nil)
        #expect(grid.foreground(column: 0, row: 1) == .red)
        #expect(grid.background(column: 0, row: 1) == .blue)
        #expect(grid.background(column: 1, row: 1) == .blue)
    }

    @Test("A nested terminal-default theme resets an inherited semantic background")
    func inheritedDefaultBackground() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                Text("B").theme(Theme())
            }.backgroundStyle(.background).theme(Theme(background: .blue)))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.background(column: 0, row: 0) == .blue)
        #expect(grid.background(column: 1, row: 0) == nil)
    }

    @Test("Semantic border styles resolve separately from content foreground")
    func borders() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Text("X").foregroundStyle(.foreground).border(.single, color: SemanticColor.accent)
                .theme(Theme(foreground: .white, accent: .green)))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .green)
        #expect(grid.foreground(column: 1, row: 1) == .white)
    }

    @Test("Validation role colors destructive actions while preserving focus and attributes")
    func validationRole() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Button("Delete", role: .destructive) {}.bold().theme(Theme(validation: .yellow)))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .yellow)
        #expect(grid.isFocused(column: 0, row: 0))
        #expect(grid.attributes(column: 0, row: 0) == [.bold])
    }

    @Test("Custom style collaborators receive the nearest theme")
    func customStyle() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("X").foregroundStyle(CustomStyle()).theme(Theme(accent: .magenta)))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .magenta)
    }

    private struct CustomStyle: Style {
        func resolve(in theme: Theme) -> Color? { theme.accent }
    }
}

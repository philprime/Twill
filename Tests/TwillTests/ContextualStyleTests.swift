import Testing

@testable import Twill

@Suite("Contextual foreground styles and tint")
@MainActor
struct ContextualStyleTests {
    @Test("Secondary retains the inherited hue and primary restores its prominence")
    func hierarchy() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                Text("B").foregroundStyle(.secondary)
                Text("C").foregroundStyle(.primary).foregroundStyle(.secondary)
                Text("D").foregroundStyle(Color.red).foregroundStyle(.secondary)
            }.foregroundStyle(Color.blue).bold())

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .blue)
        #expect(grid.foreground(column: 1, row: 0) == .blue)
        #expect(grid.foreground(column: 2, row: 0) == .blue)
        #expect(grid.foreground(column: 3, row: 0) == .red)
        #expect(grid.attributes(column: 0, row: 0) == [.bold])
        #expect(grid.attributes(column: 1, row: 0) == [.bold, .dim])
        #expect(grid.attributes(column: 2, row: 0) == [.bold])
        #expect(grid.attributes(column: 3, row: 0) == [.bold])
    }

    @Test("Secondary uses terminal-default foreground without inventing a palette color")
    func terminalHierarchy() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(Text("Detail").foregroundStyle(.secondary))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == nil)
        #expect(grid.attributes(column: 0, row: 0) == [.dim])
    }

    @Test("Local attribute overrides can clear hierarchical emphasis while nearer styles can restore it")
    func attributePrecedence() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A").dim(false).foregroundStyle(.secondary)
                Text("B").foregroundStyle(.secondary).dim(false)
                Text("C").textAttributes([]).foregroundStyle(AccentStyle()).bold()
                Text("D").foregroundStyle(.secondary).underline(false).foregroundStyle(AccentStyle())
            }.foregroundStyle(Color.blue))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.attributes(column: 0, row: 0).isEmpty)
        #expect(grid.attributes(column: 1, row: 0) == [.dim])
        #expect(grid.attributes(column: 2, row: 0).isEmpty)
        #expect(grid.attributes(column: 3, row: 0) == [.dim])
        #expect(grid.foreground(column: 0, row: 0) == .blue)
    }

    @Test("Nested tint overrides re-resolve inherited declarations without affecting siblings")
    func nestedTints() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                Text("B").tint(.green).foregroundStyle(.secondary)
                Text("C").foregroundStyle(Color.blue)
            }.foregroundStyle(.tint).tint(.red))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .red)
        #expect(grid.foreground(column: 1, row: 0) == .green)
        #expect(grid.foreground(column: 2, row: 0) == .blue)
        #expect(grid.attributes(column: 1, row: 0) == [.dim])
        #expect(grid.attributes(column: 2, row: 0).isEmpty)
    }

    @Test("Tint emphasizes unstyled buttons without recoloring ordinary text or explicit labels")
    func controlTint() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A")
                Button("B") {}
                Button(action: {}, label: { Text("C").foregroundStyle(Color.blue) })
                Button("D", role: .destructive) {}
                Button("E") {}.foregroundStyle(Color.magenta)
            }.tint(.cyan))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == nil)
        #expect(grid.foreground(column: 1, row: 0) == .cyan)
        #expect(grid.foreground(column: 2, row: 0) == .blue)
        #expect(grid.foreground(column: 3, row: 0) == .red)
        #expect(grid.foreground(column: 4, row: 0) == .magenta)
        #expect(grid.isFocused(column: 1, row: 0))
    }

    @Test("A nil tint clears the inherited override")
    func tintReset() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            HStack(spacing: 0) {
                Text("A").foregroundStyle(.tint)
                Text("B").foregroundStyle(.tint).tint(nil)
            }.tint(.red))

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .red)
        #expect(grid.foreground(column: 1, row: 0) == nil)
    }

    @Test("A hierarchical border styles its rings without dimming its content")
    func borderHierarchy() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Text("X").border(.single, color: .secondary).foregroundStyle(Color.blue).bold())

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .blue)
        #expect(grid.foreground(column: 1, row: 1) == .blue)
        #expect(grid.attributes(column: 0, row: 0) == [.bold, .dim])
        #expect(grid.attributes(column: 1, row: 1) == [.bold])
    }

    @Test("Custom styles resolve context into color and attributes")
    func customStyle() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            Text("X").foregroundStyle(AccentStyle()).tint(.magenta).bold())

        // -- Act --
        let grid = try #require(renderer.render(.now).grid)

        // -- Assert --
        #expect(grid.foreground(column: 0, row: 0) == .magenta)
        #expect(grid.attributes(column: 0, row: 0) == [.bold, .underline])
    }

    @Test("Explicit terminal-default styles clear inherited color and background paint")
    func terminalDefaults() throws {
        // -- Arrange --
        let renderer = ViewRenderer.make(
            VStack(alignment: .leading) {
                Text("AB").foregroundStyle(TerminalDefault()).backgroundStyle(TerminalDefault())
                Text("C")
            }.foregroundStyle(Color.red).backgroundStyle(Color.blue))

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

    private struct AccentStyle: Style {
        func resolve(in context: StyleContext) -> ResolvedStyle {
            ResolvedStyle(color: context.tint, attributes: [.underline])
        }
    }

    private struct TerminalDefault: Style {
        func resolve(in context: StyleContext) -> ResolvedStyle { ResolvedStyle(color: nil) }
    }
}

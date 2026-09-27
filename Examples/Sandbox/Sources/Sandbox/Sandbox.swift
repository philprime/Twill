import Twill

@main
struct Sandbox {
    @MainActor
    static func main() async throws {
        let application = Twill.Application(rootView: ColorGrid())
        try await application.run()
    }
}

private struct ColorGrid: View {
    private struct Swatch: Identifiable {
        let name: String
        let color: Color

        var id: String { name }
    }

    private struct Row: Identifiable {
        let id: Int
        let swatches: [Swatch]
    }

    private let rows = [
        Row(
            id: 0,
            swatches: [
                Swatch(name: "black", color: .black),
                Swatch(name: "red", color: .red),
                Swatch(name: "green", color: .green),
                Swatch(name: "yellow", color: .yellow),
            ]),
        Row(
            id: 1,
            swatches: [
                Swatch(name: "blue", color: .blue),
                Swatch(name: "magenta", color: .magenta),
                Swatch(name: "cyan", color: .cyan),
                Swatch(name: "white", color: .white),
            ]),
        Row(
            id: 2,
            swatches: [
                Swatch(name: "bright black", color: .brightBlack),
                Swatch(name: "bright red", color: .brightRed),
                Swatch(name: "bright green", color: .brightGreen),
                Swatch(name: "bright yellow", color: .brightYellow),
            ]),
        Row(
            id: 3,
            swatches: [
                Swatch(name: "bright blue", color: .brightBlue),
                Swatch(name: "bright magenta", color: .brightMagenta),
                Swatch(name: "bright cyan", color: .brightCyan),
                Swatch(name: "bright white", color: .brightWhite),
            ]),
    ]

    var body: some View {
        VStack {
            Text("Colors")
                .border(.single, color: Color.white)
            VStack(spacing: 1) {
                ForEach(rows) { row in
                    HStack(spacing: 2) {
                        ForEach(row.swatches) { swatch in
                            HStack(spacing: 1) {
                                Text("    ").backgroundStyle(swatch.color)
                                Text(swatch.name).frame(width: 15)
                            }
                        }
                    }
                }
            }
            .border(.single, color: Color.white)
        }
    }
}

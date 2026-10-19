import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Styled control terminal interaction")
@MainActor
struct ControlStyleApplicationTests {
    @Test("Presentation styling preserves disabled routing, adjustment and terminal cleanup", .timeLimit(.minutes(1)))
    func styledControls() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var result: (Bool, Int)?
        let application = Application(
            rootView: StyledFixture(report: { result = ($0, $1) }).controlStyle(QuietStyle()),
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array(" \t\u{1B}[Cs\u{3}".utf8)) } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()
        let output = try #require(String(data: data, encoding: .utf8))

        // -- Assert --
        #expect(result?.0 == true)
        #expect(result?.1 == 3)
        #expect(output.contains("2 items"))
        #expect(output.contains("\u{1B}[90m"))
        #expect(!output.contains("\u{1B}[7m"))
        #expect(try terminal.snapshot() == original)
    }
}

private struct QuietStyle: ControlStyle {
    func resolve(_ state: ControlState, in theme: Theme) -> ControlAppearance {
        ControlAppearance(foreground: state.isEnabled ? SemanticColor.accent : .muted, focusEffect: .none)
    }
}

@MainActor
private struct StyledFixture: View {
    @State private var isOn = false
    @State private var count = 2
    let report: @MainActor (Bool, Int) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Button("Unavailable") {}.disabled(true)
            Toggle("Flag", isOn: $isOn)
            Stepper("Count", value: $count, in: 0...5, format: { "\($0) items" })
        }.onKeyPress { key in
            guard key == .s else { return .ignored }
            report(isOn, count)
            return .handled
        }
    }
}

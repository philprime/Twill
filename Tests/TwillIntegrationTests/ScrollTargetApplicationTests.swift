import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Anchored scroll target terminal interaction")
@MainActor
struct ScrollTargetApplicationTests {
    @Test("Explicit targets scroll without moving control focus and restore terminal settings", .timeLimit(.minutes(1)))
    func explicitTarget() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let loop = DefaultRunLoop()
        var activations = 0
        var requests: [String] = []
        let application = Application(
            rootView: ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Button("Focus") { activations += 1 }
                        ForEach(1..<5, id: \.self) { Text("Row \($0)") }
                        Text("Target").id("target")
                        ForEach(6..<10, id: \.self) { Text("Row \($0)") }
                    }
                }.frame(height: 3).onKeyPress { key in
                    switch key {
                    case .G:
                        proxy.scrollTo("target", anchor: .center)
                        requests.append("center")
                    case .g:
                        proxy.scrollTo("target", anchor: .nearest)
                        requests.append("nearest")
                    default: return .ignored
                    }
                    return .handled
                }
            },
            runLoop: loop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        loop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do { try terminal.send(Array("Gg\r\u{3}".utf8)) } catch {
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
        #expect(output.contains("Focus"))
        #expect(requests == ["center", "nearest"])
        #expect(activations == 1)
        #expect(try terminal.snapshot() == original)
    }
}

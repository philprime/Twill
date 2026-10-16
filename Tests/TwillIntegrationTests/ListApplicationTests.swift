import Foundation
import Testing
import Twill

@Suite("List application input")
@MainActor
struct ListApplicationTests {
    @Test(
        "List selection handles terminal keys before application shortcuts and restores terminal modes",
        .timeLimit(.minutes(1)))
    func selectionAndSubmission() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var selection: Int? = 0
        var activated: [Int?] = []
        var applicationKeys: [KeyEvent] = []
        let application = Application(
            rootView: List(0..<5, id: \.self, selection: Binding(get: { selection }, set: { selection = $0 })) {
                Text("Row \($0)")
            }
            .frame(height: 2)
            .onSubmit { activated.append(selection) },
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.onKeyEvent = { [weak application] key in
            applicationKeys.append(key)
            if key == .q { application?.stop() }
        }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Down, Down, Enter, End, Enter, q, delivered in one input batch.
                    try terminal.send([0x1B, 0x5B, 0x42, 0x1B, 0x5B, 0x42, 0x0D, 0x1B, 0x5B, 0x46, 0x0D, 0x71])
                } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let output = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(selection == 4)
        #expect(activated == [2, 4])
        #expect(applicationKeys == [.q])
        #expect(output.contains(Data("Row 0".utf8)))
        #expect(try terminal.snapshot() == original)
    }
}

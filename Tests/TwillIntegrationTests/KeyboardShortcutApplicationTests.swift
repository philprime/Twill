import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Scoped shortcut application input")
@MainActor
struct KeyboardShortcutApplicationTests {
    @Test(
        "Terminal shortcuts respect editing, disabled actions and lifecycle policy",
        .timeLimit(.minutes(1)), arguments: [false, true])
    func shortcutDelivery(reserveControlC: Bool) async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXON | IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        var saved: [String] = []
        var controlCActions = 0
        var fallback: [KeyEvent] = []
        let application = Application(
            rootView: ShortcutFixture(onSave: { saved.append($0) }, onControlC: { controlCActions += 1 }),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))))
        application.options.ui.mode = .inline
        application.options.exitOnControlC = reserveControlC
        application.options.exitOnControlD = true
        application.onKeyEvent = { [weak application] key in
            fallback.append(key)
            // A routing regression must fail the assertion rather than leave the app running.
            if key == .d.withModifiers(.control) { application?.stop() }
        }
        runLoop.add(
            Twill.Timer(interval: .milliseconds(1)) {
                do {
                    // Initial Save is disabled. Typing enables it, and each save
                    // must leave editing focus intact. Lifecycle policy owns exit.
                    let controlS: UInt8 = 0x13
                    let superS = Array("\u{1B}[115;9u".utf8)
                    let enhancedControlC = Array("\u{1B}[99;5u".utf8)
                    let enhancedControlD = Array("\u{1B}[100;5u".utf8)
                    try terminal.send([controlS, 0x61, controlS, 0x62] + superS + enhancedControlC + enhancedControlD)
                } catch {
                    Issue.record(error)
                    application.stop()
                }
            })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let data = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()

        // -- Assert --
        #expect(saved == ["a", "ab"])
        #expect(controlCActions == (reserveControlC ? 0 : 1))
        #expect(fallback == [.controlS])
        #expect(data.contains(Data("Ctrl-S".utf8)))
        #expect(try terminal.snapshot() == original)
    }
}

@MainActor
private struct ShortcutFixture: View {
    @State private var name = ""
    private let saveShortcut = KeyboardShortcut(.controlS)
    let onSave: @MainActor (String) -> Void
    let onControlC: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: $name)
            Button("Save") { onSave(name) }.disabled(name.isEmpty)
                .keyboardShortcut([saveShortcut, KeyboardShortcut(.superS)])
            Button("Control-C action", action: onControlC)
                .keyboardShortcut([KeyboardShortcut(.controlC), KeyboardShortcut(.c.withModifiers(.control))])
            Text("\(saveShortcut.hint): save")
        }
    }
}

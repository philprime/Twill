import Foundation
import Testing
import Twill

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif

@Suite("Image application presentation")
@MainActor
struct ImageApplicationTests {
    @Test("Image resources are deleted before the borrowed terminal is restored", .timeLimit(.minutes(1)))
    func imageRoundTrip() async throws {
        // -- Arrange --
        let terminal = try TestTerminal()
        try terminal.configure { $0.c_iflag |= tcflag_t(IXOFF | IXANY) }
        let original = try terminal.snapshot()
        let pipe = Pipe()
        let runLoop = DefaultRunLoop()
        let data = Data(
            base64Encoded:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")!
        let application = Application(
            rootView: ImageView(try Image(pngData: data), width: 4, height: 2),
            runLoop: runLoop,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(pipe.fileHandleForWriting.fileDescriptor))
            )
        )
        runLoop.add(Twill.Timer(interval: .milliseconds(1)) { application.stop() })

        // -- Act --
        try await application.run()
        try pipe.fileHandleForWriting.close()
        let bytes = try #require(try pipe.fileHandleForReading.readToEnd())
        try pipe.fileHandleForReading.close()
        let output = try #require(String(data: bytes, encoding: .utf8))

        // -- Assert --
        #expect(output.contains("a=T,t=d,f=100,q=2,C=1"))
        #expect(output.contains(data.base64EncodedString()))
        let deletion = try #require(output.range(of: "a=d,d=I"))
        let restoration = try #require(output.range(of: "\u{1B}[?1049l"))
        #expect(deletion.lowerBound < restoration.lowerBound)
        #expect(try terminal.snapshot() == original)
    }
}

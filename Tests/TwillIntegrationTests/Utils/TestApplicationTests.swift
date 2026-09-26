import Foundation
import Testing

@Suite("Test application harness")
struct TestApplicationTests {
    @Test("Captures separate terminal lines and terminates the application")
    func capturesLines() throws {
        // -- Arrange --
        let application = try TestApplication(
            executablePath: "/bin/sh",
            arguments: ["-c", "printf 'first\\nsecond\\n'; exec sleep 30"]
        )
        defer { application.terminate() }

        // -- Act --
        try application.launch()
        let first = try application.waitForLine()
        let second = try application.waitForLine()
        application.terminate()

        // -- Assert --
        #expect(first == "first")
        #expect(second == "second")
        #expect(!application.isRunning)
    }

    @Test("Launches with the requested terminal dimensions")
    func terminalDimensions() throws {
        // -- Arrange --
        let application = try TestApplication(
            executablePath: "/bin/sh",
            arguments: ["-c", "stty size"],
            rows: 35,
            columns: 100
        )
        defer { application.terminate() }

        // -- Act --
        try application.launch()
        let size = try application.waitForLine()

        // -- Assert --
        #expect(size == "35 100")
    }

    @Test("Uses the requested grace period before forcing termination")
    func terminationTimeout() throws {
        // -- Arrange --
        let application = try TestApplication(
            executablePath: "/bin/sh",
            arguments: ["-c", "trap '' TERM; printf 'ready\\n'; exec sleep 30"]
        )
        defer { application.terminate() }
        try application.launch()
        let ready = try application.waitForLine()
        let clock = ContinuousClock()

        // -- Act --
        let start = clock.now
        application.terminate(timeout: 0.05)
        let elapsed = start.duration(to: clock.now)

        // -- Assert --
        #expect(ready == "ready")
        #expect(!application.isRunning)
        #expect(elapsed >= .milliseconds(50))
        #expect(elapsed < .seconds(1))
    }

    @Test("Waiting for output has a bounded timeout")
    func timesOut() throws {
        // -- Arrange --
        let application = try TestApplication(
            executablePath: "/bin/sh", arguments: ["-c", "exec sleep 30"]
        )
        defer { application.terminate() }
        try application.launch()

        // -- Act --
        let result = Result { try application.waitForLine(timeout: 0.05) }

        // -- Assert --
        switch result {
        case .failure(TestApplicationError.timedOut):
            break
        default:
            Issue.record("Expected an output timeout, received \(result)")
        }
    }
}

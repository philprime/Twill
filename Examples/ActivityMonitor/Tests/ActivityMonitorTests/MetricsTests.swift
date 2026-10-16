import Foundation
import Testing

@testable import ActivityMonitor

struct MetricsTests {
    @Test func parsesProcessesWithoutSplittingCommandNames() throws {
        // -- Arrange --
        let output = " 42 1 501 125.4 2048 S /Applications/My Tool.app/Contents/MacOS/My Tool\ninvalid\n"

        // -- Act --
        let processes = ProcessSample.parse(output)

        // -- Assert --
        let process = try #require(processes.first)
        #expect(processes.count == 1)
        #expect(process.id == 42)
        #expect(process.parentID == 1)
        #expect(process.userID == 501)
        #expect(process.cpuPercent == 125.4)
        #expect(process.residentBytes == 2_097_152)
        #expect(process.command == "/Applications/My Tool.app/Contents/MacOS/My Tool")
    }

    @Test func rejectsInvalidProcessNumbers() {
        // -- Arrange --
        let output = "42 1 501 nan 20 S command\n43 1 501 1 -20 S command\n"

        // -- Act --
        let processes = ProcessSample.parse(output)

        // -- Assert --
        #expect(processes.isEmpty)
    }

    @Test func measuresCPUFromCounterDifferences() {
        // -- Arrange --
        let previous = CPUTicks(busy: 100, idle: 100)
        let current = CPUTicks(busy: 125, idle: 175)

        // -- Act --
        let usage = current.usage(since: previous)

        // -- Assert --
        #expect(usage == 25)
        #expect(current.usage(since: nil) == nil)
        #expect(current.usage(since: current) == nil)
        #expect(previous.usage(since: current) == nil)
    }

    @Test func linuxCPUExcludesGuestCountersAndCountsIOWaitAsIdle() throws {
        // -- Arrange --
        let contents = "cpu  10 2 3 80 5 4 6 1 8 2\ncpu0 10 2 3 80\n"

        // -- Act --
        let ticks = try CPUTicks.linux(contents)

        // -- Assert --
        #expect(ticks.busy == 26)
        #expect(ticks.idle == 85)
    }

    @Test func linuxMemoryUsesAvailableNotJustFree() throws {
        // -- Arrange --
        let contents = "MemTotal: 1000 kB\nMemFree: 100 kB\nMemAvailable: 400 kB\n"

        // -- Act --
        let memory = try MemorySample.linux(contents)

        // -- Assert --
        #expect(memory.totalBytes == 1_024_000)
        #expect(memory.usedBytes == 614_400)
        #expect(memory.percent == 60)
        #expect(throws: (any Error).self) { try MemorySample.linux("MemTotal: 1000 kB") }
    }

    @Test func samplesTheRealMachine() async throws {
        // -- Arrange --
        let sampler = SystemSampler()
        let currentPID = Int(ProcessInfo.processInfo.processIdentifier)

        // -- Act --
        let sample = try await sampler.sample()

        // -- Assert --
        #expect(sample.processes.contains { $0.id == currentPID })
        #expect(sample.memory.totalBytes > 0)
        #expect(sample.memory.usedBytes <= sample.memory.totalBytes)
        #expect(sample.cpuPercent == nil)
    }

    @Test func historyKeepsOnlyRecentSamples() {
        // -- Arrange --
        var history = MetricHistory(capacity: 3)

        // -- Act --
        for value in 1...5 { history.append(Double(value)) }

        // -- Assert --
        #expect(history.values == [3, 4, 5])
    }
}

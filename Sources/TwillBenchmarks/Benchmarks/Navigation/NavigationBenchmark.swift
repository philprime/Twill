import Foundation
import Twill

struct NavigationBenchmark: SDKBenchmark {
    let name = "navigation"
    let summary = "Held-key list navigation through a real PTY. Arguments: [key-count=60] [keys-per-second=60]"

    func run(arguments: [String]) async throws -> BenchmarkResult {
        guard arguments.count <= 2,
            let count = Int(arguments.first ?? "60"), (1...100_000).contains(count),
            let rate = Int(arguments.dropFirst().first ?? "60"), (1...10_000).contains(rate)
        else { throw BenchmarkError.invalidArguments }
        let measurement = try await Self.measure(count: count, rate: rate)
        return BenchmarkResult(
            name: name,
            context: "\(count) keys at \(rate)/s, 120x40, 24 notes, fullscreen, output=/dev/null; "
                + "latency ends at selection, drain ends at input sentinel, not display",
            metrics: [
                .milliseconds("input-to-selection", samples: measurement.metrics.latencies),
                .milliseconds("input-queue-drain", samples: [measurement.metrics.drain]),
                .milliseconds("producer-scheduling-delay-max", samples: [measurement.producerDelay]),
            ])
    }

    static func measure(count: Int, rate: Int) async throws -> (metrics: NavigationMetrics, producerDelay: Duration) {
        let terminal = try BenchmarkTerminal()
        let workload = NavigationWorkload(count: count, rate: rate)
        var latencies: [Duration] = []
        var completed: ContinuousClock.Instant?
        let readiness = AsyncStream<Void>.makeStream()
        let root = NavigationBenchmarkView {
            let now = ContinuousClock.now
            let sent = workload.samples.withLock { $0.sent[latencies.count] }
            latencies.append(sent.duration(to: now))
        }
        .task { readiness.continuation.yield(()) }
        let application = Application(
            rootView: root,
            terminalSession: DefaultTerminalSession(
                fileDescriptor: .custom(terminal.terminal.fileDescriptor),
                output: DefaultTerminalOutput(fileDescriptor: .custom(terminal.sink.fileDescriptor))),
            terminalViewport: DefaultTerminalViewport(fileDescriptor: .custom(terminal.terminal.fileDescriptor)))
        application.options.ui.mode = .fullscreen
        application.onKeyEvent = { [weak application] key in
            if key == .exclamationMark {
                completed = .now
                application?.stop()
            }
        }
        try await drive(application, workload: workload, host: terminal.host, readiness: readiness)
        guard latencies.count == count, let completed,
            let release = workload.samples.withLock({ $0.release })
        else { throw BenchmarkError.incomplete(received: latencies.count, expected: count) }
        let metrics = NavigationMetrics(latencies: latencies, releaseToCompletion: release.duration(to: completed))
        return (metrics, workload.samples.withLock { $0.maximumProducerDelay })
    }

    private static func drive(
        _ application: Application, workload: NavigationWorkload, host: FileHandle,
        readiness: (stream: AsyncStream<Void>, continuation: AsyncStream<Void>.Continuation)
    ) async throws {
        let runLoop = Task {
            defer { readiness.continuation.finish() }
            try await application.run()
        }
        // Mounting signals readiness only after raw mode and the initial frame are established.
        for await _ in readiness.stream { break }
        // A separate executor keeps UI stalls from reducing the offered load.
        let producer = Task.detached { try await workload.send(to: host) }
        let timeout = Task {
            do {
                try await Task.sleep(for: .seconds(max(30, workload.count / workload.rate * 10)))
                producer.cancel()
                application.stop()
            } catch {}
        }
        var producerError: (any Error)?
        do {
            try await producer.value
        } catch {
            producerError = error
            application.stop()
        }
        do {
            try await runLoop.value
        } catch {
            timeout.cancel()
            await timeout.value
            throw error
        }
        timeout.cancel()
        await timeout.value
        if let producerError { throw producerError }
    }

}

import Foundation
import Synchronization

/// Shared with the input producer so UI actor stalls cannot slow the offered key rate.
final class NavigationWorkload: Sendable {
    private static let keysPerDirection = 20
    private static let nextPane = Data([0x09])
    private static let arrowDown = Data([0x1B, 0x5B, 0x42])
    private static let arrowUp = Data([0x1B, 0x5B, 0x41])
    private static let completionSentinel = Data([0x21])

    struct Samples {
        var sent: [ContinuousClock.Instant] = []
        var release: ContinuousClock.Instant?
        var maximumProducerDelay: Duration = .zero
    }

    let samples = Mutex(Samples())
    let count: Int
    let rate: Int

    init(count: Int, rate: Int) {
        self.count = count
        self.rate = rate
    }

    func send(to terminal: FileHandle) async throws {
        // The search field initially owns focus, as in the interactive browser.
        try terminal.write(contentsOf: Self.nextPane)
        let clock = ContinuousClock()
        let start = clock.now
        let interval = Duration.seconds(1) / rate
        for index in 0..<count {
            try Task.checkCancellation()
            let deadline = start + interval * index
            try await clock.sleep(until: deadline)
            let now = clock.now
            samples.withLock {
                $0.sent.append(now)
                $0.maximumProducerDelay = max($0.maximumProducerDelay, deadline.duration(to: now))
                $0.release = now
            }
            // Reverse before reaching either end, keeping every key observable as a selection change.
            let arrow = (index / Self.keysPerDirection).isMultiple(of: 2) ? Self.arrowDown : Self.arrowUp
            try terminal.write(contentsOf: arrow)
        }
        // FIFO sentinel measures completion of queued input, not the final painted frame.
        try terminal.write(contentsOf: Self.completionSentinel)
    }
}

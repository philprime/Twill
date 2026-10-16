import Foundation

struct CPUTicks: Sendable {
    let busy: UInt64
    let idle: UInt64

    func usage(since previous: Self?) -> Double? {
        guard let previous, busy >= previous.busy, idle >= previous.idle else { return nil }
        let busyDelta = Double(busy - previous.busy)
        let totalDelta = busyDelta + Double(idle - previous.idle)
        return totalDelta > 0 ? busyDelta / totalDelta * 100 : nil
    }

    static func linux(_ contents: String) throws -> Self {
        let fields = contents.split(separator: "\n").first?.split(whereSeparator: \.isWhitespace) ?? []
        let counters = fields.dropFirst().prefix(8).compactMap { UInt64($0) }
        guard fields.first == "cpu", counters.count == 8 else { throw SamplingError.unavailable("CPU counters") }
        // Guest time is already included in user/nice. I/O wait is not CPU execution.
        return Self(
            busy: counters[0] + counters[1] + counters[2] + counters[5] + counters[6] + counters[7],
            idle: counters[3] + counters[4])
    }
}

struct MemorySample: Sendable {
    let usedBytes: UInt64
    let totalBytes: UInt64

    var percent: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0 }
    var label: String { "\(Self.format(usedBytes)) / \(Self.format(totalBytes))" }

    static func format(_ bytes: UInt64) -> String {
        let gibibyte = 1_073_741_824.0
        if Double(bytes) >= gibibyte { return String(format: "%.1f GiB", Double(bytes) / gibibyte) }
        return String(format: "%.1f MiB", Double(bytes) / 1_048_576)
    }

    static func linux(_ contents: String) throws -> Self {
        var values: [String: UInt64] = [:]
        for line in contents.split(separator: "\n") {
            let fields = line.split(whereSeparator: \.isWhitespace)
            if fields.count >= 2, let value = UInt64(fields[1]), value <= UInt64.max / 1024 {
                values[String(fields[0])] = value * 1024
            }
        }
        guard let total = values["MemTotal:"], total > 0,
            let available = values["MemAvailable:"], available <= total
        else { throw SamplingError.unavailable("memory counters") }
        return Self(usedBytes: total - available, totalBytes: total)
    }
}

struct MetricHistory {
    private(set) var values: [Double] = []
    let capacity: Int

    init(capacity: Int = 90) {
        precondition(capacity > 0)
        self.capacity = capacity
    }

    mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }
}

struct SystemSnapshot: Sendable {
    let date: Date
    let cpuPercent: Double?
    let memory: MemorySample
    let processes: [ProcessSample]
}

enum SamplingError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let metric): "Unable to read \(metric)."
        }
    }
}

struct BenchmarkMetric {
    let name: String
    let unit: String
    let samples: [Double]

    func percentile(_ fraction: Double) -> Double {
        let sorted = samples.sorted()
        let index = max(0, Int((Double(sorted.count) * fraction).rounded(.up)) - 1)
        return sorted[index]
    }

    static func milliseconds(_ name: String, samples: [Duration]) -> Self {
        Self(
            name: name, unit: "ms",
            samples: samples.map {
                let parts = $0.components
                return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
            })
    }
}

import Foundation

struct BenchmarkResult {
    let name: String
    let context: String
    let metrics: [BenchmarkMetric]

    var formatted: String {
        let measurements = metrics.map { metric in
            if metric.samples.count == 1 {
                return "  \(metric.name): \(Self.format(metric.samples[0])) \(metric.unit)"
            }
            return "  \(metric.name) (\(metric.samples.count) samples, \(metric.unit)): "
                + "p50=\(Self.format(metric.percentile(0.5))) p95=\(Self.format(metric.percentile(0.95))) "
                + "max=\(Self.format(metric.percentile(1)))"
        }
        return (["\(name): \(context)"] + measurements).joined(separator: "\n")
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

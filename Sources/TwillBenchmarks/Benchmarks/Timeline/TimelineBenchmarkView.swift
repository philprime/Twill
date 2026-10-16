import Foundation
import Twill

/// Timeline siblings update on controlled dates without rebuilding the static rows.
struct TimelineBenchmarkView: View {
    let start: Date
    let rowCount: Int
    let changesOutput: Bool
    let onFast: @MainActor () -> Void
    let onSlow: @MainActor () -> Void
    let onStatic: @MainActor () -> Void

    var body: some View {
        HStack {
            VStack {
                TimelineView(.periodic(from: start, by: 1)) { context -> Text in
                    onFast()
                    return Text(changesOutput ? "Tick \(Int(context.date.timeIntervalSince(start)))" : "Tick")
                }
                TimelineView(.periodic(from: start, by: 10)) { context -> Text in
                    onSlow()
                    return Text(changesOutput ? "Slow \(Int(context.date.timeIntervalSince(start)))" : "Slow")
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<rowCount, id: \.self) { index in
                        StaticRow(index: index, onBody: onStatic)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private struct StaticRow: View {
        let index: Int
        let onBody: @MainActor () -> Void

        var body: some View {
            onBody()
            return Text("Static record \(index)")
        }
    }
}

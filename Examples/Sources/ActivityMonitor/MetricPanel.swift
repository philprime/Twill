import Foundation
import Twill

struct MetricPanel: View {
    let title: String
    let detail: String
    let values: [Double]
    let color: Color

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading) {
                Text(detail).foregroundStyle(color)
                Canvas { context, size in
                    let samples = values.suffix(size.width)
                    let blocks: [Character] = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
                    let offset = size.width - samples.count
                    for (index, value) in samples.enumerated() {
                        let height = Int((min(100, max(0, value)) / 100 * Double(size.height * 8)).rounded())
                        for row in 0..<size.height {
                            let level = min(8, max(0, height - (size.height - 1 - row) * 8))
                            context.draw(
                                blocks[level], column: offset + index, row: row,
                                foreground: color)
                        }
                    }
                }
                .frame(height: 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

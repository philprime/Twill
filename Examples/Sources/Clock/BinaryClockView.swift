import Foundation
import Twill

struct BinaryClockView: View {
    var body: some View {
        Canvas(interval: 1.0 / 5.0) { context, size in
            let time = ClockTime(context.date)
            guard size.width >= 26, size.height >= 9 else {
                let originX = max(0, (size.width - time.label.count) / 2)
                for (offset, character) in time.label.enumerated() {
                    context.draw(
                        character, column: originX + offset, row: size.height / 2, foreground: ClockPalette.minutes)
                }
                return
            }
            let rowSpacing = size.height >= 17 ? 2 : 1
            let originX = (size.width - 26) / 2
            let originY = (size.height - (6 * rowSpacing + 3)) / 2
            let values = [time.hour, time.minute, time.second]
            let colors = [ClockPalette.hours, ClockPalette.minutes, ClockPalette.seconds]
            for bit in 0..<6 {
                let weight = 1 << (5 - bit)
                let label = String(format: "%2d", weight)
                for (offset, character) in label.enumerated() {
                    context.draw(
                        character, column: originX + offset, row: originY + bit * rowSpacing,
                        foreground: ClockPalette.muted)
                }
                for index in 0..<3 {
                    let isOn = values[index] & weight != 0
                    let column = originX + 6 + index * 8
                    for offset in 0..<3 {
                        context.draw(
                            isOn ? "█" : "░", column: column + offset, row: originY + bit * rowSpacing,
                            foreground: isOn ? colors[index] : ClockPalette.track)
                    }
                }
            }
            for (index, label) in ["HRS", "MIN", "SEC"].enumerated() {
                let column = originX + 6 + index * 8
                for (offset, character) in label.enumerated() {
                    context.draw(
                        character, column: column + offset, row: originY + 6 * rowSpacing, foreground: colors[index])
                }
                let value = String(format: "%02d", values[index])
                for (offset, character) in value.enumerated() {
                    context.draw(
                        character, column: column + offset, row: originY + 6 * rowSpacing + 2, foreground: colors[index]
                    )
                }
            }
        }
    }
}

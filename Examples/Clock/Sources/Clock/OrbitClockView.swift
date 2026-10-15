import Foundation
import Twill

struct OrbitClockView: View {
    var body: some View {
        Canvas(interval: 1.0 / 30.0) { context, size in
            let time = ClockTime(context.date)
            let centerX = Double(size.width - 1) / 2
            let centerY = Double(size.height - 1) / 2
            let radius = min(Double(size.width - 4) / 4, Double(size.height - 3) / 2)
            if radius >= 4 {
                let turns = [time.hourTurn, time.minuteTurn, time.secondTurn]
                let colors = [ClockPalette.hours, ClockPalette.minutes, ClockPalette.seconds]
                for index in 0..<3 {
                    let ringRadius = radius * (0.5 + Double(index) * 0.25)
                    let samples = max(60, Int(ringRadius * 30))
                    for step in 0..<samples {
                        let turn = Double(step) / Double(samples)
                        let angle = turn * 2 * Double.pi
                        let isFilled = turn <= turns[index]
                        context.draw(
                            isFilled ? "•" : "·",
                            column: Int((centerX + 2 * ringRadius * sin(angle)).rounded()),
                            row: Int((centerY - ringRadius * cos(angle)).rounded()),
                            foreground: isFilled ? colors[index] : ClockPalette.track)
                    }
                    let angle = turns[index] * 2 * Double.pi
                    context.draw(
                        "●", column: Int((centerX + 2 * ringRadius * sin(angle)).rounded()),
                        row: Int((centerY - ringRadius * cos(angle)).rounded()), foreground: colors[index])
                }
            }
            let originX = max(0, (size.width - time.label.count) / 2)
            for (offset, character) in time.label.enumerated() {
                context.draw(
                    character, column: originX + offset, row: size.height / 2, foreground: ClockPalette.foreground)
            }
        }
    }
}

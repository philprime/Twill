import Foundation
import Twill

@main
struct Clock {
    @MainActor
    static func main() async throws {
        try await Twill.Application(rootView: ClockView()).run()
    }
}

struct ClockView: View {
    var body: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 0.05)) { context in
                Text(
                    context.date.formatted(
                        .dateTime.hour().minute().second()
                            .secondFraction(.fractional(3))
                    ))
            }
            AnalogClockView()
        }
    }
}

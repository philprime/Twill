import Foundation
import Twill

@main
struct Clock {
    @MainActor
    static func main() async throws {
        let application = Twill.Application(rootView: ClockView())
        try await application.run()
    }
}

struct ClockView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            Text(
                context.date.formatted(
                    .dateTime.hour().minute().second()
                        .secondFraction(.fractional(3))
                ))
        }
    }
}

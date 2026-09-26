import Foundation
import Twill

@main
struct Clock {
    @MainActor
    static func main() async {
        let runLoop = Twill.DefaultRunLoop()
        let application = Twill.Application(runLoop: runLoop)

        let timer = Twill.Timer(interval: .seconds(1), repeats: true) {
            print(Date.now.formatted(date: .omitted, time: .standard))
        }
        runLoop.add(timer)

        await application.run()
    }
}

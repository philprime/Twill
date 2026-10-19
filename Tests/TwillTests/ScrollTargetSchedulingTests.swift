import Foundation
import Testing

@testable import Twill

@Suite("Scroll target scheduling")
@MainActor
struct ScrollTargetSchedulingTests {
    @Test("Anchored requests preserve keyed phases and removed targets release nodes")
    func deadlinesAndRemoval() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var proxy: ScrollViewProxy?
        var dates: [Int: [Date]] = [:]
        func content(_ ids: [Int]) -> some View {
            ScrollViewReader { supplied in
                proxy = supplied
                return ScrollView {
                    VStack(spacing: 0) {
                        ForEach(ids, id: \.self) { id in
                            TimelineView(.periodic(from: start, by: id == 1 ? 10 : 20)) { context in
                                dates[id, default: []].append(context.date)
                                return Text("\(id)")
                            }
                        }
                    }
                }.frame(height: 1)
            }
        }
        let renderer = ViewRenderer.make(content([1, 2]))
        _ = renderer.render(start)
        weak var row: ViewRenderer?
        row = renderer.keyedNode(for: 2)
        let existed = row != nil

        // -- Act --
        proxy?.scrollTo(2, anchor: .center)
        _ = renderer.drawFrame(proposal: .unspecified)
        let next = renderer.nextUpdate
        _ = renderer.render(start.addingTimeInterval(10))
        renderer.update(content([1]), at: start.addingTimeInterval(11))
        let removed = renderer.render(start.addingTimeInterval(11))
        proxy?.scrollTo(2, anchor: .nearest)

        // -- Assert --
        #expect(existed && row == nil)
        #expect(next == start.addingTimeInterval(10))
        #expect(removed.nextUpdate == start.addingTimeInterval(20))
        #expect(dates[1] == [start, start.addingTimeInterval(10), start.addingTimeInterval(10)])
        #expect(dates[2] == [start])
    }

    @Test("Already-visible nearest targets do not write another frame")
    func unchangedOutput() throws {
        // -- Arrange --
        let output = RecordingTerminalOutput()
        let host = ViewHost(
            rootView: ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) { ForEach(0..<5, id: \.self) { Text("\($0)") } }
                }.frame(height: 2).onKeyPress { key in
                    guard key == .n else { return .ignored }
                    proxy.scrollTo(0, anchor: .nearest)
                    return .handled
                }
            }, runLoop: RecordingRunLoop(), output: output)
        try host.start()
        defer { host.stop() }
        let writes = output.writes

        // -- Act --
        let handled = host.handle(.n)

        // -- Assert --
        #expect(handled)
        #expect(output.writes == writes)
    }
}

import Foundation
import Testing

@testable import Twill

@Suite("Typed view composition")
@MainActor
struct ViewBuilderTests {
    @Test("View lists retain their heterogeneous child types in a tuple")
    func typedChildren() {
        // -- Arrange --
        let start = Date(timeIntervalSinceReferenceDate: 100)
        let timeline = TimelineView(.periodic(from: start, by: 1)) { _ in Text("Clock") }
        let content: ViewList<Text, TimelineView<Text>> = ViewBuilder.buildBlock(Text("Label"), timeline)
        let children: (Text, TimelineView<Text>) = content.children

        // -- Act --
        let label = ViewRenderer.make(children.0).render(start)
        let clock = ViewRenderer.make(children.1).render(start)

        // -- Assert --
        #expect(label.grid?.snapshotText == "Label")
        #expect(clock.grid?.snapshotText == "Clock")
        #expect(clock.nextUpdate == start.addingTimeInterval(1))
    }

    @Test("Stacks preserve their builder's concrete composition type")
    func typedStack() {
        // -- Arrange --
        let stack: HStack<ViewList<Text, Text>> = HStack {
            Text("Hello")
            Text("World")
        }

        // -- Act --
        let frame = ViewRenderer.make(stack).render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "Hello World")
        #expect(frame.nextUpdate == nil)
    }

    @Test("A group forwards its typed children without adding spacing")
    func transparentGroup() {
        // -- Arrange --
        let group: Group<ViewList<Text, Text>> = Group {
            Text("First")
            Text("Second")
        }

        // -- Act --
        let frame = ViewRenderer.make(group).render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "FirstSecond")
        #expect(frame.nextUpdate == nil)
    }

    @Test("Conditional composition retains both branch types", arguments: [false, true])
    func typedBranches(visible: Bool) {
        // -- Arrange --
        typealias Branch = ConditionalContent<ViewList<Text>, ViewList<EmptyView>>
        let stack: HStack<ViewList<Branch>> = HStack {
            if visible { Text("Visible") } else { EmptyView() }
        }

        // -- Act --
        let frame = ViewRenderer.make(stack).render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == (visible ? "Visible" : nil))
    }

    @Test("Optional composition uses a typed empty branch", arguments: [false, true])
    func typedOptional(visible: Bool) {
        // -- Arrange --
        typealias Branch = ConditionalContent<ViewList<Text>, EmptyView>
        let stack: HStack<ViewList<Branch>> = HStack {
            if visible { Text("Visible") }
        }

        // -- Act --
        let frame = ViewRenderer.make(stack).render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == (visible ? "Visible" : nil))
    }

    @Test("Empty parameter packs produce no presentation")
    func emptyStack() {
        // -- Arrange --
        let stack = HStack {}

        // -- Act --
        let frame = ViewRenderer.make(stack).render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == nil)
        #expect(frame.nextUpdate == nil)
    }

    @Test("Parameter packs do not impose a fixed child-count limit")
    func manyChildren() {
        // -- Arrange --
        let stack = HStack(spacing: 0) {
            Text("0")
            Text("1")
            Text("2")
            Text("3")
            Text("4")
            Text("5")
            Text("6")
            Text("7")
            Text("8")
            Text("9")
            Text("A")
            Text("B")
        }

        // -- Act --
        let frame = ViewRenderer.make(stack).render(.now)

        // -- Assert --
        #expect(frame.grid?.snapshotText == "0123456789AB")
    }
}

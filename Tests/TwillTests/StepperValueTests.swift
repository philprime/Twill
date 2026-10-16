import Testing

@testable import Twill

@Suite("Stepper numeric boundaries")
@MainActor
struct StepperValueTests {
    @Test("Default bounds saturate signed integer overflow without wrapping")
    func signedOverflow() {
        // -- Arrange --
        var value: Int8 = 126
        var writes: [Int8] = []
        let renderer = ViewRenderer.make(
            Stepper(
                "Count",
                value: Binding(
                    get: { value },
                    set: {
                        value = $0
                        writes.append($0)
                    }), step: 10))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowRight)
        let upper = value
        value = -127
        _ = renderer.handle(.arrowLeft)
        _ = renderer.handle(.arrowLeft)

        // -- Assert --
        #expect(upper == 127)
        #expect(value == -128)
        #expect(writes == [127, -128])
    }

    @Test("Unsigned steppers clamp overflow and underflow to explicit bounds")
    func unsignedOverflow() {
        // -- Arrange --
        var value: UInt8 = 249
        let renderer = ViewRenderer.make(
            Stepper("Count", value: Binding(get: { value }, set: { value = $0 }), in: 2...250, step: 10))
        _ = renderer.render(.now)

        // -- Act --
        _ = renderer.handle(.arrowRight)
        let upper = value
        value = 3
        _ = renderer.handle(.arrowLeft)

        // -- Assert --
        #expect(upper == 250)
        #expect(value == 2)
    }

    @Test("External out-of-range values stay unchanged until an available adjustment restores the range")
    func externalValues() throws {
        // -- Arrange --
        var value = -10
        var writes: [Int] = []
        let renderer = ViewRenderer.make(
            Stepper(
                "Count",
                value: Binding(
                    get: { value },
                    set: {
                        value = $0
                        writes.append($0)
                    }), in: 0...10, step: 2))

        // -- Act --
        let initial = try #require(renderer.render(.now).grid)
        _ = renderer.handle(.arrowLeft)
        let unchanged = value
        _ = renderer.handle(.arrowRight)
        value = 20
        _ = renderer.handle(.arrowRight)
        _ = renderer.handle(.arrowLeft)

        // -- Assert --
        #expect(initial.snapshotText == "(-) Count: -10 [+]")
        #expect(unchanged == -10)
        #expect(writes == [0, 10])
        #expect(value == 10)
    }

    @Test("An external change is used by the next adjustment even before presentation")
    func liveBinding() {
        // -- Arrange --
        var value = -4
        let renderer = ViewRenderer.make(
            Stepper("Count", value: Binding(get: { value }, set: { value = $0 }), in: -5...5))
        _ = renderer.render(.now)

        // -- Act --
        value = 4
        _ = renderer.handle(.arrowLeft)

        // -- Assert --
        #expect(value == 3)
    }
}

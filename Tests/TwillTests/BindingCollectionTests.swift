import Testing

@testable import Twill

@Suite("Collection element bindings")
@MainActor
struct BindingCollectionTests {
    @Test("An indexed write preserves the latest collection contents")
    func writesLatestCollection() {
        // -- Arrange --
        var values = ["First", "Second"]
        let binding = Binding(get: { values }, set: { values = $0 })
        let first = binding[0]
        values = ["Replaced", "Updated", "Appended"]
        let latest = first.wrappedValue

        // -- Act --
        first.wrappedValue = "Edited"

        // -- Assert --
        #expect(latest == "Replaced")
        #expect(values == ["Edited", "Updated", "Appended"])
    }

    @Test("Element bindings use the collection's actual indices")
    func sliceIndex() {
        // -- Arrange --
        var values = ["Zero", "One", "Two", "Three"][2...]
        let binding = Binding(get: { values }, set: { values = $0 })
        let first = binding[values.startIndex]

        // -- Act --
        first.wrappedValue = "Edited"

        // -- Assert --
        #expect(values.startIndex == 2)
        #expect(Array(values) == ["Edited", "Three"])
    }

    @Test("An element projection of a constant collection ignores writes")
    func constantCollection() {
        // -- Arrange --
        let binding = Binding.constant(["Fixed", "Sibling"])

        // -- Act --
        binding[0].wrappedValue = "Edited"

        // -- Assert --
        #expect(binding.wrappedValue == ["Fixed", "Sibling"])
    }
}

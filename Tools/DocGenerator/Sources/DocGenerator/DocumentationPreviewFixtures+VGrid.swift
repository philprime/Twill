@testable import Twill

extension DocumentationPreviewFixture {
    static var eagerGrid: Self {
        Self("VGrid", "Eager fixed columns with independent row and column gaps.") {
            VGrid(columns: [GridItem(.fixed(6)), GridItem(.fixed(6))], rowSpacing: 0, columnSpacing: 2) {
                Text("One")
                Text("Two")
                Text("Three")
                Text("Four")
            }
        }
    }
}

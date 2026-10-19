@testable import Twill

extension DocumentationPreviewFixture {
    static var indicatedScroll: Self {
        Self("ScrollIndicatorView", "Visible indicators reserve one right-hand terminal column.") {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) { ForEach(0..<6, id: \.self) { Text("Row \($0)") } }
            }.scrollIndicators(.visible).frame(width: 8, height: 3)
        }
    }
}

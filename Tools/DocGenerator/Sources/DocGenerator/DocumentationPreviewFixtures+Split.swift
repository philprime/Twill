@testable import Twill

extension DocumentationPreviewFixture {
    static var paneFixtures: [Self] {
        [
            Self("SplitView", "Fixed and flexible panes share width without changing keyboard traversal.") {
                SplitView(leadingWidth: .fixed(6), spacing: 2) {
                    Text("Left")
                } trailing: {
                    Text("Right")
                }
                .frame(width: 20, height: 2)
            }
        ]
    }
}

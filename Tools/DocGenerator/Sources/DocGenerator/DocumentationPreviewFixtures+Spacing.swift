@testable import Twill

extension DocumentationPreviewFixture {
    static var spacingPrimitives: [Self] {
        [
            Self("Spacer", "Flexible space pushes siblings apart along the stack's axis.", proposal: .init(width: 20)) {
                HStack {
                    Text("Left")
                    Spacer()
                    Text("Right")
                }
            },
            Self("Divider", "A separator spans the stack's minor axis and inherits appearance.") {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Above")
                    Divider()
                    Text("Below")
                }
            },
        ]
    }
}

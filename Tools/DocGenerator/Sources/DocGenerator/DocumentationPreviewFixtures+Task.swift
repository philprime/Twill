@testable import Twill

extension DocumentationPreviewFixture {
    static var taskFixtures: [Self] {
        [
            Self("KeyedTaskView", "Task identity restarts owned work without replacing ordinary content identity.") {
                Text("Restartable work").task(id: 1) {}
            }
        ]
    }
}

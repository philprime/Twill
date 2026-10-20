@testable import Twill

extension DocumentationPreviewFixture {
    static var observationFixtures: [Self] {
        [
            Self(
                "ChangeObservationView",
                "Equatable observation preserves ordinary content and delivers after reconciliation."
            ) {
                Text("Observed content").onChange(of: 1, initial: true) { _, _ in }
            }
        ]
    }
}

@testable import Twill

private struct SheetPreviewPayload: Identifiable {
    let id: Int
    let title: String
}

extension DocumentationPreviewFixture {
    static var itemSheet: Self {
        Self("ItemSheetView", "A payload presents content keyed by its identity, retaining the base page.") {
            Text("Base page").sheet(item: .constant(SheetPreviewPayload(id: 1, title: "Selected payload"))) { payload in
                GroupBox("Details") { Text(payload.title) }
            }.frame(width: 24, height: 5)
        }
    }
}

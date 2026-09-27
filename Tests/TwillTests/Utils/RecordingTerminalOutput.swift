import Twill

@MainActor
final class RecordingTerminalOutput: TerminalOutput {
    private(set) var writes: [String] = []
    var failure: Error?
    var nextFailure: Error?
    var onWrite: ((String) -> Void)?

    func write(_ text: String) throws {
        MainActor.assertIsolated()
        if let nextFailure {
            self.nextFailure = nil
            throw nextFailure
        }
        if let failure { throw failure }
        writes.append(text)
        onWrite?(text)
    }
}

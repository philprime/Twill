struct BenchmarkCommand {
    enum Action {
        case help
        case list
        case run(name: String, repetitions: Int, arguments: [String])
    }

    let action: Action

    init(arguments: [String]) throws {
        if arguments == ["--help"] {
            action = .help
            return
        }
        if arguments == ["--list"] {
            action = .list
            return
        }
        var remaining = arguments[...]
        let name = remaining.first.map { $0.hasPrefix("--") ? "all" : remaining.removeFirst() } ?? "all"
        var repetitions = 1
        if remaining.first == "--repeat" {
            remaining.removeFirst()
            guard let value = remaining.first.flatMap(Int.init), (1...1_000).contains(value) else {
                throw BenchmarkError.invalidArguments
            }
            repetitions = value
            remaining.removeFirst()
        }
        if !remaining.isEmpty {
            guard remaining.removeFirst() == "--" else { throw BenchmarkError.invalidArguments }
        }
        action = .run(name: name, repetitions: repetitions, arguments: Array(remaining))
    }
}

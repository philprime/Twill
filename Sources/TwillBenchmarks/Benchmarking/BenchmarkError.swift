enum BenchmarkError: Error {
    case invalidArguments
    case unknownBenchmark(String)
    case systemCall(Int32)
    case incomplete(received: Int, expected: Int)
}

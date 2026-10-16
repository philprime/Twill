struct NavigationMetrics {
    let latencies: [Duration]
    let releaseToCompletion: Duration

    var drain: Duration { max(.zero, releaseToCompletion) }
}

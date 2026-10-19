/// An identity or endpoint conflict in a graph mutation.
public enum GraphNetworkError<ID: Hashable & Sendable>: Error, Equatable {
    /// The initial node collection contains an identity more than once.
    case duplicateNode(ID)
    /// An edge references an absent endpoint.
    case missingNode(ID)
    /// A connection with the same ordered endpoints already exists.
    case duplicateEdge(source: ID, target: ID)
}

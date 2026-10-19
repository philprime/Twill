/// A base class used to exercise inheritance extraction.
public class Base {}
/// A subtype whose compiler symbol graph references its base.
public final class Derived: Base {}
/// An actor whose protocol conformance is discoverable by the compiler.
public actor ActorWorker: Service {}
struct InternalType {}
private struct Hidden {}

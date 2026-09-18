extension Operation {
    // The Call of an interface: one case per operation (its Application) and per child (its Call), run by the
    // owner through `run(owner, call)`.
    public protocol Coproduct: ~Copyable, ~Escapable {
        associatedtype Cases
        associatedtype Owner

        static var cases: Cases { get }

        static func run(_ owner: Owner, _ call: consuming Self) async throws
    }
}

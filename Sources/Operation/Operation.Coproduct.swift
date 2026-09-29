extension Operation {
    public protocol Coproduct: ~Copyable, ~Escapable {
        associatedtype Cases
        associatedtype Owner

        static var cases: Cases { get }

        static func run(_ owner: Owner, _ call: consuming Self) async throws
    }
}

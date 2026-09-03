extension Operation {
    public protocol Coproduct: ~Copyable, ~Escapable {
        associatedtype Operations: ~Copyable & ~Escapable

        associatedtype Cases

        static var cases: Cases { get }
    }
}

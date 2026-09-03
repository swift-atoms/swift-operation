extension Operation {
    public protocol Coproduct: ~Copyable, ~Escapable {
        associatedtype Operations: ~Copyable & ~Escapable
    }
}

extension Operation {
    public protocol Member: Symbol, ~Copyable, ~Escapable {
        associatedtype Coproduct: Operation.Coproduct & ~Copyable

        associatedtype Case

        static var keyPath: KeyPath<Coproduct.Cases, Case> { get }
    }
}

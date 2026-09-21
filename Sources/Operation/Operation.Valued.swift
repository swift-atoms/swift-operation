extension Operation {
    // A composed operation whose input and output are values, as its owner lists it: a reader of the list runs
    // the symbol without its declaration in scope.
    public protocol Valued<Owner> {
        associatedtype Owner
        associatedtype Symbol: Composed where Symbol.Owner == Owner, Symbol.Input: Copyable, Symbol.Output: Copyable
    }

    // The witness that a symbol's sorts are values, when they are. Whether they are is not visible in the
    // symbol's declaration, so the compiler decides here: `valued` is the witness for value sorts and nil for
    // a transferred input or a noncopyable output.
    public enum Valuation<Symbol: Composed> {
        public static var valued: (any Valued<Symbol.Owner>.Type)? { nil }
    }
}

extension Operation.Valuation: Operation.Valued where Symbol.Input: Copyable, Symbol.Output: Copyable {
    public typealias Owner = Symbol.Owner
    public static var valued: (any Operation.Valued<Symbol.Owner>.Type)? { Self.self }
}

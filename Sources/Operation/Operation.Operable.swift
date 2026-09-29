extension Operation {
    public protocol Operable: Symbol where Input: Escapable, Output: Escapable {
        static func run(_ owner: Owner, _ input: consuming Input) async throws -> Output
    }

    public protocol Composed: Operable {
        associatedtype Call: ~Copyable, Coproduct where Call.Owner == Owner

        static func call(_ input: consuming Input) -> Call
    }
}

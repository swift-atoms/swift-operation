extension Operation {
    // A symbol that knows how its owner runs it: `Symbol.run(owner, input)`. The owner itself carries no
    // protocol — an interface's inheritance clause names its own nested protocol, and a conformance added by
    // an extension macro there is a circular reference — so everything generic about running an operation
    // goes through its symbol.
    // Its sorts escape: running yields the output to whoever asked.
    public protocol Operable: Symbol where Input: Escapable, Output: Escapable {
        static func run(_ owner: Owner, _ input: consuming Input) async throws -> Output
    }

    // A symbol whose owner is an interface: its Call is the owner's, and runs the same way.
    public protocol Composed: Operable {
        associatedtype Call: ~Copyable, Coproduct where Call.Owner == Owner

        /// This operation, as a call of its interface.
        static func call(_ input: consuming Input) -> Call

        /// The input of a call of this operation; nil when the call is another operation's.
        static func input(from call: consuming Call) -> Input?
    }
}

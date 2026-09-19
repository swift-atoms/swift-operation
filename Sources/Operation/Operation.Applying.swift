extension Operation {
    // What a Call's leaf summand is: something built from an operation's Input and giving it back. The Call is
    // generic in its leaves (so that the compiler decides its capabilities) and builds them through this. Leaves
    // are Escapable: a Call is (its prisms return it from stored arrows).
    public protocol Applying<Input>: ~Copyable {
        associatedtype Input: ~Copyable

        init(_ input: consuming Input)

        consuming func consume() -> Input
    }
}

extension Operation._Application: Operation.Applying where Input: ~Copyable & Escapable {}

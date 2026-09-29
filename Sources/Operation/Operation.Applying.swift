extension Operation {
    public protocol Applying<Input>: ~Copyable {
        associatedtype Input: ~Copyable

        init(_ input: consuming Input)

        consuming func consume() -> Input
    }
}

extension Operation._Application: Operation.Applying where Input: ~Copyable & Escapable {}

extension Operation {
    // An input of one field, built from that field: `Input(draft)` is `Input(draft: draft)`. A feature whose state
    // is such an input can be built from the field directly.
    public protocol Unary {
        associatedtype Field

        init(_ field: Field)
    }
}

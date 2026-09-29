extension Operation {
    public protocol Unary {
        associatedtype Field

        init(_ field: Field)
    }
}

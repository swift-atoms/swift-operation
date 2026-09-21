extension Operation {
    // An input of no fields, built from nothing: an operation that asks nothing of its caller can be run by
    // anyone holding its owner.
    public protocol Nullary {
        init()
    }
}

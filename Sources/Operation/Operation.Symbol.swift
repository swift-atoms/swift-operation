extension Operation {
    // One operation, by name: its three sorts, and the interface that declares it.
    public protocol Symbol: ~Copyable, ~Escapable {
        associatedtype Input: ~Copyable & ~Escapable
        associatedtype Output: ~Copyable & ~Escapable
        associatedtype Failure: ~Copyable & ~Escapable
        associatedtype Owner = Never
    }
}

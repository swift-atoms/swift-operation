extension Operation {
    public protocol Symbol: ~Copyable, ~Escapable {
        associatedtype Input: ~Copyable & ~Escapable
        associatedtype Output: ~Copyable & ~Escapable
        associatedtype Failure: ~Copyable & ~Escapable
    }
}

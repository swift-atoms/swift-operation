extension Operation {
    // A Call whose operations can be named again as functions that hand each built Call to a sender:
    // `Sending` is the interface's `Embedding<Void>`, so `store.delete(id)` is `store.send(.delete(id))`.
    public protocol Sending: ~Copyable {
        associatedtype Sending

        static func sending(_ send: @escaping (consuming Self) -> Void) -> Sending
    }
}

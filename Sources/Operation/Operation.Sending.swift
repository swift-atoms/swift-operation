extension Operation {
    public protocol Sending: ~Copyable {
        associatedtype Sending

        static func sending(_ send: @escaping (consuming Self) -> Void) -> Sending
    }
}

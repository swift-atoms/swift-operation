extension Operation {
    public protocol Labelled<Value>: Symbol where Output: Copyable & Escapable {
        associatedtype Label: CaseIterable & Hashable
        associatedtype Value
        static func value(of output: Output, at label: Label) -> Value
    }
}

extension Operation {
    // An operation whose output is a labelled product of one value type: the labels are a finite index, and
    // the output is read at a label. A reader names each conclusion by its label without reflecting the tuple.
    public protocol Labelled<Value>: Symbol where Output: Copyable & Escapable {
        associatedtype Label: CaseIterable & Hashable
        associatedtype Value
        static func value(of output: Output, at label: Label) -> Value
    }
}

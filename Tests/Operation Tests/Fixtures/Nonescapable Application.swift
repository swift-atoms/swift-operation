import Operation

enum View: ~Escapable {
    case value(Int)
}

enum Inspect: Operation.Symbol {
    typealias Input = View
    typealias Output = Void
    typealias Failure = Never
}

func requireEscapable<Value: Escapable>(_: Value) {}

func prove() {
    let application = Operation.Application<Inspect>(.value(42))
    requireEscapable(application)
}

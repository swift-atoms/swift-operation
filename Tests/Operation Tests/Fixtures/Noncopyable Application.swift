import Operation

struct Token: ~Copyable {}

enum Consume: Operation.Symbol {
    typealias Input = Token
    typealias Output = Void
    typealias Failure = Never
}

func requireCopyable<Value: Copyable>(_: Value) {}

func prove() {
    let application = Operation.Application<Consume>(Token())
    requireCopyable(application)
}

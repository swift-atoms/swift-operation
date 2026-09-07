import Operation

enum Echo: Operation.Symbol {
    typealias Input = Int
    typealias Output = String
    typealias Failure = Never
}

func prove() -> Int {
    let application = Operation.Application<Echo>(42)
    return application.consume()
}

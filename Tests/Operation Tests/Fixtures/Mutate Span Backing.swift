import Operation
enum Inspect: Operation.Symbol { typealias Input = Span<Int>; typealias Output = Void; typealias Failure = Never }
func check() {
    var values = [1, 2]
    let application = Operation.Application<Inspect>(values.span)
    values[0] = 42
    print(application.input[0])
}

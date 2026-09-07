import Operation
struct Resource: ~Copyable {}
enum Use: Operation.Symbol { typealias Input = Resource; typealias Output = Void; typealias Failure = Never }
func check() {
    let application = Operation.Application<Use>(Resource())
    let first = application.consume()
    let second = application.consume()
    _ = consume first
    _ = consume second
}

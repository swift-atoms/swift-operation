import Operation
enum Inspect: Operation.Symbol { typealias Input = Span<Int>; typealias Output = Void; typealias Failure = Never }
@_lifetime(immortal)
func escape() -> Operation.Application<Inspect> {
    let values = [1, 2]
    return .init(values.span)
}

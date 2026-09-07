import Operation
enum First: Operation.Symbol { typealias Input = Int; typealias Output = String; typealias Failure = Never }
enum Second: Operation.Symbol { typealias Input = Int; typealias Output = String; typealias Failure = Never }
func accept(_: Operation.Application<First>) {}
func check() { accept(Operation.Application<Second>(42)) }

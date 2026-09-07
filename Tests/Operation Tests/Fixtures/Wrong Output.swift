import Operation
struct OutputA: ~Copyable {}
struct OutputB: ~Copyable {}
enum Use: Operation.Symbol { typealias Input = Int; typealias Output = OutputA; typealias Failure = Never }
func accept<Index: Operation.Symbol>(_: borrowing Operation.Application<Index>, output: consuming Index.Output) where Index.Output: ~Copyable & ~Escapable {}
func check() { accept(Operation.Application<Use>(42), output: OutputB()) }

import Operation
struct FailureA: ~Copyable {}
struct FailureB: ~Copyable {}
enum Use: Operation.Symbol { typealias Input = Int; typealias Output = Void; typealias Failure = FailureA }
func accept<Index: Operation.Symbol>(_: borrowing Operation.Application<Index>, failure: consuming Index.Failure) where Index.Failure: ~Copyable & ~Escapable {}
func check() { accept(Operation.Application<Use>(42), failure: FailureB()) }

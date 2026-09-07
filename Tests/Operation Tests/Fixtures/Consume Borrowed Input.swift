import Operation
struct Resource: ~Copyable {}
enum Use: Operation.Symbol { typealias Input = Resource; typealias Output = Void; typealias Failure = Never }
func check(_ application: borrowing Operation.Application<Use>) -> Resource { application.input }

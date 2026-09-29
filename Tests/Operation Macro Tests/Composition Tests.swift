import Operation_Macro
import Testing

private struct Independent {
    @Operations
    protocol Ports {
        func increment(_ value: Int) -> Int
    }

    func increment(_ input: Increment.Input) -> Int { input.value + 1 }

    enum Call: Operation.Coproduct {
        case increment(Increment.Application)
        typealias Owner = Independent
        typealias Cases = Void
        static var cases: Void { () }
        static func increment(_ input: Increment.Input) -> Self { .increment(.init(input)) }
        static func run(_ owner: Owner, _ call: consuming Self) async throws {
            switch call { case .increment(let application): _ = owner.increment(application.consume()) }
        }
    }
}

@Test func `operation composition has no frontend dependency`() {
    let owner = Independent()
    #expect(Independent.Increment.run(owner, .init(4)) == 5)
    let call = Independent.Increment.call(.init(9))
    switch call { case .increment(let application): #expect(application.value == 9) }
}

extension Independent.Increment.Input: Hashable, Sendable {}

extension Independent.Increment: Operation.Composed {
    fileprivate typealias Call = Independent.Call
    fileprivate static func call(_ input: consuming Input) -> Call { .increment(input) }
    fileprivate static func run(_ owner: Independent, _ input: consuming Input) -> Output { owner.increment(input) }
}

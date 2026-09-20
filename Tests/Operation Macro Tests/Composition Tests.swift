import Operation_Macro
import Testing

// An explicit composition contract works without @Interface, its nested protocol name, or its plugin.
private struct Independent {
    @Operations(composed: true)
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
    #expect(Independent.Increment.input(from: call)?.value == 9)
}

// Capabilities are declared using Swift protocols at the point of use.
extension Independent.Increment.Input: Hashable, Sendable {}

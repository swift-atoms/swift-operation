import Operation
import Testing

private enum Echo: Operation.Symbol {
    typealias Input = String
    typealias Output = Int
    typealias Failure = Never
}

private struct Payload: ~Copyable {
    var value: Int
}

private struct Refusal: ~Copyable {}
private struct Product: ~Copyable {}

private enum Consume: Operation.Symbol {
    typealias Input = Payload
    typealias Output = Void
    typealias Failure = Refusal
}

private enum Produce: Operation.Symbol {
    typealias Input = String
    typealias Output = Product
    typealias Failure = Refusal
}

private struct ScopedOutput: ~Escapable {}
private struct ScopedFailure: ~Escapable {}

private enum Observe: Operation.Symbol {
    typealias Input = String
    typealias Output = ScopedOutput
    typealias Failure = ScopedFailure
}

private enum View: ~Escapable {
    case value(Int)
}

private enum Inspect: Operation.Symbol {
    typealias Input = View
    typealias Output = Void
    typealias Failure = Never
}

private func requireCopyable<Value: Copyable>(_: Value) {}
private func requireEscapable<Value: Escapable>(_: Value) {}
private func requireCopyableIndependently<Value: Copyable & ~Escapable>(
    _: borrowing Value
) {}
private func requireEscapableIndependently<Value: ~Copyable & Escapable>(
    _: borrowing Value
) {}

@Suite
private struct `Operation Tests` {
    @Test
    func `operation symbol associates its three sorts`() {
        let _: Echo.Input.Type = String.self
        let _: Echo.Output.Type = Int.self
        let _: Echo.Failure.Type = Never.self
    }

    @Test
    func `application tags a value with its operation symbol`() {
        let application = Operation.Application<Echo>("forty-two")

        #expect(application.input == "forty-two")
        requireCopyable(application)
        requireEscapable(application)
    }

    @Test
    func `application supports noncopyable input and failure`() {
        let application = Operation.Application<Consume>(
            Payload(value: 42)
        )
        requireEscapableIndependently(application)
        let input = application.consume()

        #expect(input.value == 42)
    }

    @Test
    func `application capabilities depend only on stored input`() {
        let application = Operation.Application<Produce>("value")

        requireCopyable(application)
        requireEscapable(application)
    }

    @Test
    func `nonescapable result sorts do not constrain application capabilities`() {
        let application = Operation.Application<Observe>("value")

        requireCopyable(application)
        requireEscapable(application)
    }

    @Test
    func `application supports nonescapable input`() {
        let application = Operation.Application<Inspect>(
            .value(42)
        )
        requireCopyableIndependently(application)
        guard case let .value(value) = application.input else { return }
        #expect(value == 42)
    }
}

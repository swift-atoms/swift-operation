import Operation
import Synchronization
import Testing

extension Operation {
    @Suite
    struct `Applications preserve their input` {
        enum Echo: Operation.Symbol {
            typealias Input = String
            typealias Output = Int
            typealias Failure = Never
        }

        final class Counter: Sendable {
            private let storage = Mutex(0)

            var value: Int { storage.withLock { $0 } }

            func increment() { storage.withLock { $0 += 1 } }
        }

        struct Payload: ~Copyable {
            let value: Int
            let releases: Counter

            deinit { releases.increment() }
        }

        struct Refusal: ~Copyable {}
        struct Product: ~Copyable {}

        enum Consume: Operation.Symbol {
            typealias Input = Payload
            typealias Output = Void
            typealias Failure = Refusal
        }

        enum Produce: Operation.Symbol {
            typealias Input = String
            typealias Output = Product
            typealias Failure = Refusal
        }

        struct ScopedOutput: ~Escapable {}
        struct ScopedFailure: ~Escapable {}

        enum Observe: Operation.Symbol {
            typealias Input = String
            typealias Output = ScopedOutput
            typealias Failure = ScopedFailure
        }

        enum View: ~Escapable {
            case value(Int)
        }

        enum Inspect: Operation.Symbol {
            typealias Input = View
            typealias Output = Void
            typealias Failure = Never
        }

        enum Numbers: Operation.Symbol {
            typealias Input = [Int]
            typealias Output = Product
            typealias Failure = Refusal
        }

        enum InspectSpan: Operation.Symbol {
            typealias Input = Span<Int>
            typealias Output = Void
            typealias Failure = Never
        }

        struct Loan: ~Copyable, ~Escapable {
            let span: Span<Int>

            @_lifetime(copy span)
            init(_ span: Span<Int>) {
                self.span = span
            }
        }

        enum InspectLoan: Operation.Symbol {
            typealias Input = Loan
            typealias Output = Void
            typealias Failure = Never
        }

        enum ReadingFailure: Swift.Error, Equatable {
            case rejected(Int)
        }

        static func requireCopyable<Value: Copyable>(_: Value) {}
        static func requireEscapable<Value: Escapable>(_: Value) {}
        static func requireCopyableIndependently<Value: Copyable & ~Escapable>(_: borrowing Value) {}
        static func requireEscapableIndependently<Value: ~Copyable & Escapable>(_: borrowing Value) {}

        static func requireEchoSorts<Index: Operation.Symbol>(
            _ application: borrowing Operation.Application<Index>
        ) where Index.Input == String, Index.Output == Int, Index.Failure == Never {}

        static func read(_ application: borrowing Operation.Application<Consume>) -> Int {
            application.input.value
        }

        static func reject(_ application: borrowing Operation.Application<Consume>) throws(ReadingFailure) {
            throw .rejected(application.input.value)
        }

        static func destroy(_ payload: consuming Payload) {
            #expect(payload.value == 42)
        }

        static func discard(_ application: consuming Operation.Application<Consume>) {
            _ = consume application
        }

        @_lifetime(copy span)
        static func wrap(_ span: Span<Int>) -> Operation.Application<InspectSpan> {
            .init(span)
        }

        @_lifetime(copy application)
        static func unwrap(_ application: consuming Operation.Application<InspectSpan>) -> Span<Int> {
            application.consume()
        }
    }
}

extension Operation.`Applications preserve their input` {
    @Test
    func `An application preserves its signature and input capabilities`() {
        let application = Operation.Application<Self.Echo>("forty-two")
        Self.requireEchoSorts(application)

        #expect(application.input == "forty-two")
        Self.requireCopyable(application)
        Self.requireEscapable(application)
    }

    @Test
    func `An application admits noncopyable input and a non-Error failure sort`() {
        let releases = Self.Counter()
        let application = Operation.Application<Self.Consume>(Self.Payload(value: 42, releases: releases))
        Self.requireEscapableIndependently(application)
        let input = application.consume()

        #expect(input.value == 42)
    }

    @Test
    func `Noncopyable result sorts do not constrain input capabilities`() {
        let application = Operation.Application<Self.Produce>("value")

        Self.requireCopyable(application)
        Self.requireEscapable(application)
        #expect(application.input == "value")
    }

    @Test
    func `Nonescapable result sorts do not constrain input capabilities`() {
        let application = Operation.Application<Self.Observe>("value")

        Self.requireCopyable(application)
        Self.requireEscapable(application)
        #expect(application.input == "value")
    }

    @Test
    func `A nonescapable input can still be borrowed and copied`() {
        let application = Operation.Application<Self.Inspect>(.value(42))
        Self.requireCopyableIndependently(application)
        guard case let .value(value) = application.input else {
            Issue.record("Expected the stored view")
            return
        }
        #expect(value == 42)
    }

    @Test
    func `Repeated borrowing keeps the payload alive until the application is dropped`() {
        let releases = Self.Counter()
        let application = Operation.Application<Self.Consume>(Self.Payload(value: 42, releases: releases))

        #expect(Self.read(application) == 42)
        #expect(Self.read(application) == 42)
        #expect(releases.value == 0)
        Self.discard(application)
        #expect(releases.value == 1)
    }

    @Test
    func `Consuming extraction transfers the payload without destroying it`() {
        let releases = Self.Counter()
        let application = Operation.Application<Self.Consume>(Self.Payload(value: 42, releases: releases))
        let payload = application.consume()

        #expect(releases.value == 0)
        Self.destroy(payload)
        #expect(releases.value == 1)
    }

    @Test
    func `Dropping an unextracted application destroys its payload exactly once`() {
        let releases = Self.Counter()

        Self.discard(.init(Self.Payload(value: 42, releases: releases)))

        #expect(releases.value == 1)
    }

    @Test
    func `A throwing borrower leaves the application available for later use`() {
        let releases = Self.Counter()
        let application = Operation.Application<Self.Consume>(Self.Payload(value: 42, releases: releases))
        do throws(Self.ReadingFailure) {
            try Self.reject(application)
            Issue.record("Expected the borrowing consumer's failure")
        } catch {
            #expect(error == .rejected(42))
        }

        #expect(releases.value == 0)
        #expect(Self.read(application) == 42)
        Self.discard(application)
        #expect(releases.value == 1)
    }

    @Test
    func `Copyable applications snapshot their input and can be consumed independently`() {
        var values = [1, 2]
        let application = Operation.Application<Self.Numbers>(values)
        let copy = application
        values.append(3)

        #expect(application.input == [1, 2])
        #expect(copy.input == [1, 2])
        let first = application.consume()
        let second = copy.consume()
        #expect(first == [1, 2])
        #expect(second == [1, 2])
        #expect(values == [1, 2, 3])
    }

    @Test
    func `A backed span retains its lifetime through wrapping and consuming extraction`() {
        let values = [1, 2, 3]
        let application = Self.wrap(values.span)
        let first = application.input[0]
        let recovered = Self.unwrap(application)
        let last = recovered[2]

        #expect(first == 1)
        #expect(last == 3)
    }

    @Test
    func `An input can be noncopyable and nonescapable at the same time`() {
        let values = [1, 2, 3]
        let application = Operation.Application<Self.InspectLoan>(Self.Loan(values.span))
        let first = application.input.span[0]
        let loan = application.consume()
        let last = loan.span[2]

        #expect(first == 1)
        #expect(last == 3)
    }
}

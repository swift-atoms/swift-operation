extension Operation {
    public typealias Application<Index: Symbol> = _Application<Index, Index.Input>
    where Index.Input: ~Copyable & ~Escapable
}

extension Operation {
    @frozen
    public struct _Application<
        Index: Symbol,
        Input: ~Copyable & ~Escapable
    >: ~Copyable, ~Escapable where Index.Input == Input {
        public var input: Input {
            @_lifetime(copy self)
            _read { yield storage }
        }

        @_lifetime(copy self)
        public consuming func consume() -> Input {
            storage
        }

        private var storage: Input

        @_lifetime(copy input)
        public init(_ input: consuming Input) {
            storage = input
        }
    }
}

extension Operation._Application: Swift.Copyable where Input: Swift.Copyable {}

extension Operation._Application: Swift.Escapable where Input: Swift.Escapable {}

extension Operation._Application: Swift.Sendable where Input: Swift.Sendable {}

extension Operation._Application: Swift.Equatable where Input: Swift.Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage == rhs.storage
    }
}

extension Operation._Application: Swift.Hashable where Input: Swift.Hashable {
    public func hash(into hasher: inout Swift.Hasher) {
        hasher.combine(storage)
    }
}

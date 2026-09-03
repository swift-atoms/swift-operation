extension Operation {
    public typealias Application<Index: Symbol> = _Application<Index, Index.Input>
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

extension Operation._Application: Copyable where Input: Copyable {}

extension Operation._Application: Escapable where Input: Escapable {}

import Operation

struct Indexed<Index: Operation.Symbol>: ~Copyable, ~Escapable {
    private var storage: Index.Input

    @_lifetime(copy input)
    init(_ input: consuming Index.Input) {
        storage = input
    }
}

extension Indexed {
    var input: Index.Input {
        @_lifetime(copy self)
        _read { yield storage }
    }
}

extension Indexed: Copyable where Index.Input: Copyable {}
extension Indexed: Escapable where Index.Input: Escapable {}

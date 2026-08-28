import Operation

struct Indexed<Index: Operation.Symbol>: ~Copyable, ~Escapable {
    var input: Index.Input {
        @_lifetime(copy self)
        _read { yield storage }
    }

    private var storage: Index.Input

    @_lifetime(copy input)
    init(_ input: consuming Index.Input) {
        storage = input
    }
}

extension Indexed: Copyable where Index.Input: Copyable {}
extension Indexed: Escapable where Index.Input: Escapable {}

extension Operation._Application where Index: Operation.Operable, Input: ~Copyable & Escapable {
    /// Execute the canonical indexed application without erasing its result to Void or Any.
    /// This is a single indexed operation, not a heterogeneous free-program representation.
    public consuming func run(on owner: Index.Owner) async throws -> Index.Output {
        try await Index.run(owner, consume())
    }
}

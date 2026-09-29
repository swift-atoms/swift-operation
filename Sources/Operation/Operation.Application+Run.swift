extension Operation._Application where Index: Operation.Operable, Input: ~Copyable & Escapable {
    public consuming func run(on owner: Index.Owner) async throws -> Index.Output {
        try await Index.run(owner, consume())
    }
}

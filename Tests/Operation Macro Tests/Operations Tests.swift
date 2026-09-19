import Operation_Syntax
import Operation_Macro
import SwiftParser
import SwiftSyntax
import Testing

@testable import Operation_Macro_Core

struct Greeting {
    struct Name: Hashable {
        var value: String
    }

    struct Input: Hashable {}

    @Operations
    protocol Interface {
        func greet(_ name: Name) async -> String
        func echo(_ values: [Input]) throws -> Int
        func callAsFunction() -> Int
        func callAsFunction(_ id: Int) throws -> Int
        func completed(in bucket: String) -> Int
        func completed(matching prefix: String, limit: Int?) -> Int
    }
}

struct Linear {
    struct Token: ~Copyable {
        let value: Int
    }

    @Operations
    protocol Interface {
        func consume(_ token: consuming Token) -> Int
    }
}

private func requireHashable<Value: Hashable>(_: Value) {}
private func requireNoncopyable<Value: ~Copyable>(_: consuming Value) {}

@Suite
struct `Operations Tests` {
    @Test
    func `every function is a symbol whose Input is its parameters`() {
        let _: Greeting.Greet.Input.Type = Greeting.Greet.Input.self
        let _: Greeting.Greet.Output.Type = String.self
        let _: Greeting.Greet.Failure.Type = Never.self
        let _: Greeting.Echo.Failure.Type = (any Swift.Error).self
        let _: Greeting.Run.Output.Type = Int.self
        let _: Greeting.Id.Input.Type = Greeting.Id.Input.self
        let _: Greeting.CompletedIn.Input.Type = Greeting.CompletedIn.Input.self
        let _: Greeting.CompletedMatching.Input.Type = Greeting.CompletedMatching.Input.self
        var input = Greeting.Greet.Input(Greeting.Name(value: "Blob"))
        input.name.value = "Other"
        requireHashable(input)
        #expect(input.name == Greeting.Name(value: "Other"))
        #expect(Greeting.Echo.Input([.init()]).values == [Greeting.Input()])
        #expect(Greeting.CompletedMatching.Input(matching: "ab", limit: nil).prefix == "ab")
        #expect(Greeting.Greet.Application(.init(.init(value: "a"))).input.name.value == "a")
    }

    @Test
    func `a transferred parameter makes the input noncopyable`() {
        requireNoncopyable(Linear.Consume.Input(Linear.Token(value: 1)))
    }

    @Test
    func `analysis names symbols, variants and cases`() throws {
        let source = Parser.parse(
            source: """
                protocol Interface {
                    func greet(_ name: Name) async -> String
                    func callAsFunction() -> Int
                    func callAsFunction(_ id: Int) throws -> Int
                    func completed(in bucket: String) -> Int
                    func completed(matching prefix: String, limit: Int?) -> Int
                }
                """
        )
        let declaration = try #require(source.statements.first?.item.as(ProtocolDeclSyntax.self))
        let analysis = Operation.Analysis(
            declaration: declaration,
            owner: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Domain")))
        )

        #expect(analysis.diagnostics.isEmpty)
        #expect(analysis.symbols.map(\.name) == ["Greet", "Run", "Id", "CompletedIn", "CompletedMatching"])
        #expect(analysis.symbols.map(\.caseName) == ["greet", "run", "id", "completedIn", "completedMatching"])
        #expect(analysis.symbols.map(\.isPrimary) == [false, true, true, false, false])
        #expect(analysis.symbols[0].inputPath(owner: "Domain") == "Domain.Greet.Input")
        #expect(analysis.symbols[0].inputs.map(\.type.trimmedDescription) == ["Name"])
        #expect(analysis.symbols[4].construction == "matching: prefix, limit: limit")
    }
}

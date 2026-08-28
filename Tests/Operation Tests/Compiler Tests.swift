import Foundation
import Testing

@Suite
private struct `Compiler Tests` {
    @Test
    func `direct associated-type conditional conformance remains unavailable`() throws {
        let diagnostic = try typecheckFailure(named: "Indexed Application.swift")

        #expect(
            diagnostic.contains(
                "conditional conformance to suppressible protocol 'Copyable' cannot depend on 'Index.Input: Copyable'"
            )
        )
        #expect(
            diagnostic.contains(
                "conditional conformance to suppressible protocol 'Escapable' cannot depend on 'Index.Input: Escapable'"
            )
        )
    }

    @Test
    func `application is not copyable when its input is not copyable`() throws {
        let diagnostic = try typecheckFailure(named: "Noncopyable Application.swift")

        #expect(
            diagnostic.contains(
                "requires that 'Consume.Input' (aka 'Token') conform to 'Copyable'"
            )
        )
    }

    @Test
    func `application is not escapable when its input is not escapable`() throws {
        let diagnostic = try typecheckFailure(named: "Nonescapable Application.swift")

        #expect(
            diagnostic.contains(
                "requires that 'Inspect.Input' (aka 'View') conform to 'Escapable'"
            )
        )
    }

    private func typecheckFailure(named name: String) throws -> String {
        var products = Bundle.module.bundleURL
        while !FileManager.default.fileExists(
            atPath: products.appendingPathComponent("Operation.swiftmodule").path
        ) {
            let parent = products.deletingLastPathComponent()
            products = try #require(parent != products ? parent : nil)
        }
        let fixture = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        let process = Process()
        let standardError = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "swiftc",
            "-typecheck",
            "-swift-version", "6",
            "-enable-experimental-feature", "Lifetimes",
            "-module-name", "Proof",
            "-I", products.path,
            fixture.path,
        ]
        process.standardError = standardError
        try process.run()
        process.waitUntilExit()
        let diagnostic = String(
            decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )

        #expect(process.terminationStatus != 0, "Fixture unexpectedly typechecked")
        #expect(!diagnostic.contains("no such module"))
        return diagnostic
    }
}

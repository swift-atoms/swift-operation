#if os(macOS)
import Darwin
import Foundation
import Operation
import Testing

extension Operation::Operation {
    @Suite
    struct `Compiler emission enforces application ownership` {
        struct Compilation {
            let status: Int32
            let diagnostic: String
            let emittedObject: Bool
        }

        enum Failure: Swift.Error {
            case timedOut(String)
        }
    }
}

extension Operation::Operation.`Compiler emission enforces application ownership` {
    @Test
    func `A supported application emits an object successfully`() throws {
        let compilation = try Self.emit(named: "Valid Application.swift")

        #expect(compilation.status == 0, Comment(rawValue: compilation.diagnostic))
        #expect(compilation.emittedObject)
    }

    @Test
    func `Conditional input capabilities require the explicit storage parameter`() throws {
        let diagnostic = try Self.rejection(named: "Indexed Application.swift")

        #expect(diagnostic.contains("conditional conformance to suppressible protocol 'Copyable' cannot depend on 'Index.Input: Copyable'"))
        #expect(diagnostic.contains("conditional conformance to suppressible protocol 'Escapable' cannot depend on 'Index.Input: Escapable'"))
    }

    @Test
    func `An application cannot copy a noncopyable input`() throws {
        let diagnostic = try Self.rejection(named: "Noncopyable Application.swift")

        #expect(diagnostic.contains("requires that 'Consume.Input' (aka 'Token') conform to 'Copyable'"))
    }

    @Test
    func `An application cannot escape a nonescapable input`() throws {
        let diagnostic = try Self.rejection(named: "Nonescapable Application.swift")

        #expect(diagnostic.contains("requires that 'Inspect.Input' (aka 'View') conform to 'Escapable'"))
    }

    @Test
    func `Different symbols remain distinct even when their three sorts match`() throws {
        let diagnostic = try Self.rejection(named: "Different Symbols.swift")

        #expect(diagnostic.contains("cannot convert value of type 'Operation._Application<Second, Second.Input>'"))
        #expect(diagnostic.contains("expected argument type 'Operation.Application<First>'"))
    }

    @Test
    func `A consumer cannot substitute another symbol's output sort`() throws {
        let diagnostic = try Self.rejection(named: "Wrong Output.swift")

        #expect(diagnostic.contains("cannot convert value of type 'OutputB' to expected argument type 'Use.Output'"))
    }

    @Test
    func `A consumer cannot substitute another symbol's noncopyable failure sort`() throws {
        let diagnostic = try Self.rejection(named: "Wrong Failure.swift")

        #expect(diagnostic.contains("cannot convert value of type 'FailureB' to expected argument type 'Use.Failure'"))
    }

    @Test
    func `A noncopyable application cannot be consumed twice`() throws {
        let diagnostic = try Self.rejection(named: "Double Consume.swift")

        #expect(diagnostic.contains("'application' consumed more than once"))
    }

    @Test
    func `The borrowed input accessor cannot transfer its noncopyable payload`() throws {
        let diagnostic = try Self.rejection(named: "Consume Borrowed Input.swift")

        #expect(diagnostic.contains("noncopyable 'application.input' cannot be consumed"))
    }

    @Test
    func `A live span-backed application prevents mutation of its backing array`() throws {
        let diagnostic = try Self.rejection(named: "Mutate Span Backing.swift")

        #expect(diagnostic.contains("overlapping accesses to 'values', but modification requires exclusive access"))
    }

    @Test
    func `An application cannot outlive a span's local backing storage`() throws {
        let diagnostic = try Self.rejection(named: "Escape Local Span.swift")

        #expect(diagnostic.contains("lifetime-dependent value escapes its scope"))
    }

    private static func rejection(named name: String) throws -> String {
        let compilation = try emit(named: name)
        try #require(compilation.status != 0, "Fixture unexpectedly emitted successfully")
        return compilation.diagnostic
    }

    private static func emit(named name: String) throws -> Compilation {
        let manager = FileManager.default
        var products = Bundle.module.bundleURL
        while !manager.fileExists(atPath: products.appendingPathComponent("Operation.swiftmodule").path) {
            let parent = products.deletingLastPathComponent()
            products = try #require(parent != products ? parent : nil)
        }
        let resource = try #require(Bundle.module.resourceURL)
        let fixture = resource.appendingPathComponent("Fixtures").appendingPathComponent(name)
        try #require(manager.fileExists(atPath: fixture.path))

        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: directory) }
        let diagnosticURL = directory.appendingPathComponent("diagnostic.txt")
        try #require(manager.createFile(atPath: diagnosticURL.path, contents: nil))
        let diagnosticFile = try FileHandle(forWritingTo: diagnosticURL)
        defer { try? diagnosticFile.close() }
        let object = directory.appendingPathComponent("Proof.o")

        #if DEBUG
        let optimization = "-Onone"
        #else
        let optimization = "-O"
        #endif

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "swiftc", "-c", optimization,
            "-swift-version", "6",
            "-enable-experimental-feature", "Lifetimes",
            "-module-name", "Proof",
            "-I", products.path,
            fixture.path,
            "-o", object.path,
        ]
        process.standardOutput = diagnosticFile
        process.standardError = diagnosticFile
        try process.run()
        defer {
            if process.isRunning {
                _ = Darwin.kill(process.processIdentifier, SIGKILL)
            }
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(30))
        while process.isRunning && clock.now < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        guard !process.isRunning else {
            process.interrupt()
            let cancellationDeadline = clock.now.advanced(by: .seconds(1))
            while process.isRunning && clock.now < cancellationDeadline {
                Thread.sleep(forTimeInterval: 0.01)
            }
            throw Failure.timedOut(name)
        }
        process.waitUntilExit()
        let diagnostic = try String(contentsOf: diagnosticURL, encoding: .utf8)
        try #require(process.terminationReason == .exit, Comment(rawValue: diagnostic))
        for failure in ["no such module", "missing required module", "could not build module", "compiled module was created by a different version"] {
            try #require(!diagnostic.contains(failure), Comment(rawValue: diagnostic))
        }
        return Compilation(
            status: process.terminationStatus,
            diagnostic: diagnostic,
            emittedObject: manager.fileExists(atPath: object.path)
        )
    }
}
#endif

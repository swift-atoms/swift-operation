# Operation

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

`Operation.Symbol` associates an operation's input, output, and failure sorts without prescribing an interpreter. `Operation.Application<Symbol>` pairs an input with its operation at the type level so heterogeneous programs can preserve which result and failure types belong to each request.

```swift
import Operation

enum Read: Operation.Symbol {
    typealias Input = URL
    typealias Output = Data
    typealias Failure = any Error
}

let request = Operation.Application<Read>(url)
```

All three associated sorts admit `~Copyable & ~Escapable` types. An application stores only its input, so its `Copyable` and `Escapable` capabilities depend only on that input. `consume()` returns noncopyable input with consuming ownership; `input` provides a lifetime-dependent borrowed projection.

The public `Application` alias is backed by `_Application<Symbol, Input>`. The explicit input parameter is an implementation accommodation for Swift 6.4: conditional conformances to suppressible protocols cannot currently depend directly on `Symbol.Input`.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-atoms/swift-operation.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Operation", package: "swift-operation"),
    ]
)
```

Requires Swift 6.4 and macOS 27 / iOS 27 / tvOS 27 / watchOS 27 / visionOS 27 (or a matching non-Apple toolchain).

## License

Apache 2.0.

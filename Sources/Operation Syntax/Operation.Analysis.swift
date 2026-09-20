public import Type_Algebra_Syntax
public import SwiftSyntax
import SwiftSyntaxBuilder

extension Operation {
    // The functions of a protocol read as operation symbols: each function becomes one symbol, named and
    // qualified against the owner that will hold it. This is the naming table for everything derived over an
    // operation; the derivations that compose symbols (an interface, a client) read their names from here.
    //
    // | derived                     | spelling                                                                |
    // |-----------------------------|-------------------------------------------------------------------------|
    // | symbol (`Owner.X`)           | the capitalised base name; `Run` for `callAsFunction`; when the base name |
    // |                             | is overloaded, a variant suffix — the capitalised first label, or the   |
    // |                             | local name when unlabelled (`Run` itself is replaced by the variant)     |
    // | input (`Owner.X.Input`)      | the parameters as a value, initialised with the declaration's labels    |
    // | case / requirement / label   | the lower-camel symbol name (`greet`, `run`, `id`, `completedIn`)        |
    public struct Analysis {
        public struct Symbol {
            public struct Input {
                public let parameter: Signature.Parameter
                public let type: TypeSyntax
            }

            public let signature: Signature
            public let name: String
            public let variant: String?
            public let isPrimary: Bool
            public let inputs: [Input]
            public let output: TypeSyntax
            public let failure: TypeSyntax

            /// The lower-camel spelling of the symbol: its Call case, its model requirement, its label.
            public var caseName: String { "\(name.prefix(1).lowercased())\(name.dropFirst())" }

            public var algebra: Type.Operation {
                Type.Operation(caseName,
                    input: .product(inputs.map { Type.Syntax.Expression($0.type, parameters: []).algebra }),
                    output: signature.returnsVoid ? .unit : Type.Syntax.Expression(output, parameters: []).algebra,
                    effect: signature.effects.map { .init($0.trimmedDescription, scope: ["Swift", "Effects"]) })
            }

            public var transfers: Bool { inputs.contains { $0.parameter.transfersOwnership } }

            public func inputPath(owner: String) -> String { "\(owner).\(name).Input" }

            public func inputParameter(owner: String) -> String {
                "\(transfers ? "consuming " : "")\(inputPath(owner: owner))"
            }

            /// The input built from the declaration's parameters, labelled as declared.
            public var construction: String {
                inputs.map { input in
                    let declaration = input.parameter.declaration
                    let label = declaration.firstName.tokenKind == .wildcard ? "" : "\(declaration.firstName.text): "
                    return "\(label)\(input.parameter.ownedExpression.trimmedDescription)"
                }.joined(separator: ", ")
            }

            public var effects: String {
                signature.effects.map { " \($0.trimmedDescription)" } ?? ""
            }

            public var prefix: String {
                (signature.effects?.throwsClause != nil ? "try " : "")
                    + (signature.effects?.asyncSpecifier != nil ? "await " : "")
            }
        }

        public static let derived = [
            "Input", "Output", "Failure", "Application", "Run",
        ]

        public var algebra: Type.Signature { get throws { try Type.Signature(symbols.map(\.algebra)) } }

        public let declaration: ProtocolDeclSyntax
        public let owner: TypeSyntax
        /// Explicit composition contract: symbols also know the owner's Call. No frontend is inferred.
        public let isComposed: Bool
        public let symbols: [Symbol]
        public let diagnostics: [String]

        public init(
            declaration: ProtocolDeclSyntax,
            owner: TypeSyntax,
            isComposed: Bool = false,
            shadowed: Set<String> = []
        ) {
            self.declaration = declaration
            self.owner = owner
            self.isComposed = isComposed
            let functions = declaration.memberBlock.members.compactMap { $0.decl.as(FunctionDeclSyntax.self) }
            let signatures = functions.map(Signature.init)
            let counts = Dictionary(grouping: signatures, by: \.name.text).mapValues(\.count)
            let names = signatures.map { signature -> (name: String, variant: String?, isPrimary: Bool) in
                let base = signature.name.text
                let isPrimary = base == "callAsFunction"
                var variant: String?
                if counts[base, default: 0] > 1, let first = signature.parameters.first {
                    let label = first.label.text
                    variant = "\(label.prefix(1).uppercased())\(label.dropFirst())"
                }
                let stem = isPrimary ? "Run" : "\(base.prefix(1).uppercased())\(base.dropFirst())"
                let name = isPrimary ? (variant ?? stem) : "\(stem)\(variant ?? "")"
                return (name, variant, isPrimary)
            }
            let qualify = DomainQualifier(owner: owner, names: shadowed.union(Self.derived).union(names.map(\.name)))
            var reasons: [String] = []
            var seen: Set<String> = []
            symbols = zip(signatures, names).map { signature, naming in
                if !seen.insert(naming.name).inserted {
                    reasons.append("`\(signature.fullName)` and another operation would both be the symbol `\(naming.name)`")
                }
                for parameter in signature.parameters where parameter.isInout {
                    reasons.append("`\(signature.fullName)` has an inout parameter; an operation's input is an owned value, not a state transition")
                }
                if signature.declaration.genericParameterClause != nil {
                    reasons.append("`\(signature.fullName)` is generic; an operation's input is one value")
                }
                return Symbol(
                    signature: signature,
                    name: naming.name,
                    variant: naming.variant,
                    isPrimary: naming.isPrimary,
                    inputs: signature.parameters.map { Symbol.Input(parameter: $0, type: qualify.rewrite($0.valueType)) },
                    output: qualify.rewrite(signature.output),
                    failure: signature.thrownError.map(qualify.rewrite)
                        ?? TypeSyntax(stringLiteral: signature.isUntypedThrows ? "any Swift.Error" : "Never")
                )
            }
            diagnostics = reasons
        }
    }
}

// A type named like something the owner will declare (an operation's symbol, `Input`, …) is meant as the
// owner's own nested type; spell it so from inside the generated declarations.
private final class DomainQualifier: SyntaxRewriter {
    let owner: TypeSyntax
    let names: Set<String>

    init(owner: TypeSyntax, names: Set<String>) {
        self.owner = owner
        self.names = names
    }

    func rewrite(_ type: TypeSyntax) -> TypeSyntax {
        TypeSyntax(visit(type))
    }

    override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
        guard
            node.moduleSelector == nil,
            node.genericArgumentClause == nil,
            names.contains(node.name.text)
        else { return super.visit(node) }
        return TypeSyntax(
            MemberTypeSyntax(baseType: owner.trimmed, name: .identifier(node.name.text))
        )
    }
}

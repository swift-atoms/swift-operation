public import Type_Algebra_Syntax
public import SwiftSyntax

extension Operation {
    // The reading of one function signature: its parameters with their conventions, its output, its effects
    // and its failure — the three sorts of an `Operation.Symbol` — plus what forwarding a call to a stored
    // arrow needs (the closure type, the invocation). Every derivation over a function starts here.
    public struct Signature {
        public enum Convention {
            case value
            case borrowing
            case consuming
            case sending
            case `inout`
            case unsupported

            var isBorrowing: Bool {
                if case .borrowing = self { true } else { false }
            }

            var isInout: Bool {
                if case .inout = self { true } else { false }
            }
        }

        public struct Parameter {
            public let declaration: FunctionParameterSyntax
            public let localName: TokenSyntax
            public let valueType: TypeSyntax
            public let closureType: TypeSyntax
            public let convention: Convention
            public let forwardingExpression: ExprSyntax
            public let ownedExpression: ExprSyntax

            /// The label a call site writes, or the local name when the parameter is unlabelled.
            public var label: TokenSyntax {
                declaration.firstName.tokenKind == .wildcard ? localName : declaration.firstName
            }

            public var transfersOwnership: Bool {
                switch convention {
                case .consuming, .sending:
                    true
                default:
                    false
                }
            }

            public var isInout: Bool {
                if case .inout = convention { true } else { false }
            }
        }

        public let declaration: FunctionDeclSyntax
        public let name: TokenSyntax
        public let fullName: String
        public let mangled: String
        // The stored field an operation lives in: its base name, or `mangled` when the base name is overloaded.
        // Resolved by whoever reads the whole protocol, since overloading is a property of the set.
        public var storage: String
        public let parameters: [Parameter]
        public let closureType: TypeSyntax
        public let output: TypeSyntax
        public let returnsVoid: Bool
        public let thrownError: TypeSyntax?
        public let isUntypedThrows: Bool
        public let isRethrowing: Bool

        public var algebra: Type.Operation {
            Type.Operation(fullName,
                input: .product(parameters.map { Type.Syntax.Expression($0.valueType, parameters: []).algebra }),
                output: returnsVoid ? .unit : Type.Syntax.Expression(output, parameters: []).algebra,
                effect: effects.map { .init($0.trimmedDescription, scope: ["Swift", "Effects"]) })
        }

        public var effects: FunctionEffectSpecifiersSyntax? { declaration.signature.effectSpecifiers }

        /// The call of the stored arrow `_<storage>` with this signature's parameters, under its effects.
        public var invocation: ExprSyntax {
            let member = MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                declName: DeclReferenceExprSyntax(baseName: .identifier("_\(storage)"))
            )
            let callee = TupleExprSyntax(
                elements: LabeledExprListSyntax([LabeledExprSyntax(expression: member)])
            )
            let arguments = parameters.enumerated().map { offset, parameter in
                LabeledExprSyntax(
                    expression: parameter.forwardingExpression,
                    trailingComma: offset == parameters.count - 1 ? nil : .commaToken(trailingTrivia: .space)
                )
            }
            var invocation = ExprSyntax(
                FunctionCallExprSyntax(
                    calledExpression: callee,
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax(arguments),
                    rightParen: .rightParenToken()
                )
            )
            if effects?.asyncSpecifier != nil {
                invocation = ExprSyntax(
                    AwaitExprSyntax(awaitKeyword: .keyword(.await, trailingTrivia: .space), expression: invocation)
                )
            }
            if effects?.throwsClause != nil {
                invocation = ExprSyntax(
                    TryExprSyntax(tryKeyword: .keyword(.try, trailingTrivia: .space), expression: invocation)
                )
            }
            return invocation
        }

        public init(_ declaration: FunctionDeclSyntax) {
            let parameters = declaration.signature.parameterClause.parameters.map { parameter in
                let value = Self.value(of: parameter)
                let localName = parameter.secondName ?? parameter.firstName
                let reference = DeclReferenceExprSyntax(baseName: localName)
                return Parameter(
                    declaration: parameter,
                    localName: localName,
                    valueType: value.type,
                    closureType: parameter.type,
                    convention: value.convention,
                    forwardingExpression: value.convention.isInout
                        ? ExprSyntax(InOutExprSyntax(expression: reference))
                        : ExprSyntax(reference),
                    ownedExpression: value.convention.isBorrowing
                        ? ExprSyntax(
                            CopyExprSyntax(
                                copyKeyword: .keyword(.copy, trailingTrivia: .space),
                                expression: reference
                            )
                        )
                        : ExprSyntax(reference)
                )
            }
            let output = declaration.signature.returnClause?.type
                ?? TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
            let effectSpecifiers = declaration.signature.effectSpecifiers
            let throwsClause = effectSpecifiers?.throwsClause
            let closureParameters = parameters.enumerated().map { offset, parameter in
                TupleTypeElementSyntax(
                    type: parameter.closureType,
                    trailingComma: offset == parameters.count - 1 ? nil : .commaToken(trailingTrivia: .space)
                )
            }
            let typeEffects = effectSpecifiers.flatMap { effects in
                effects.asyncSpecifier == nil && effects.throwsClause == nil
                    ? nil
                    : TypeEffectSpecifiersSyntax(
                        asyncSpecifier: effects.asyncSpecifier,
                        throwsClause: effects.throwsClause
                    )
            }
            let labels = declaration.signature.parameterClause.parameters.map { parameter in
                parameter.firstName.tokenKind == .wildcard
                    ? (parameter.secondName ?? parameter.firstName).text
                    : parameter.firstName.text
            }
            let outputSpelling = output.trimmedDescription

            self.declaration = declaration
            name = declaration.name
            fullName = "\(declaration.name.text)(\(labels.map { "\($0):" }.joined()))"
            mangled = ([declaration.name.text] + labels).joined(separator: "_")
            storage = mangled
            self.parameters = parameters
            closureType = TypeSyntax(
                FunctionTypeSyntax(
                    parameters: TupleTypeElementListSyntax(closureParameters),
                    rightParen: .rightParenToken(trailingTrivia: .space),
                    effectSpecifiers: typeEffects,
                    returnClause: ReturnClauseSyntax(arrow: .arrowToken(trailingTrivia: .space), type: output)
                )
            )
            self.output = output
            returnsVoid = outputSpelling == "Void" || outputSpelling == "()"
            thrownError = throwsClause?.type
            isUntypedThrows = throwsClause != nil && throwsClause?.type == nil
            isRethrowing = throwsClause?.throwsSpecifier.tokenKind == .keyword(.rethrows)
        }

        private static func value(
            of parameter: FunctionParameterSyntax
        ) -> (type: TypeSyntax, convention: Convention) {
            guard var attributed = parameter.type.as(AttributedTypeSyntax.self) else {
                return (parameter.type, .value)
            }
            var convention = Convention.value
            for specifier in attributed.specifiers {
                guard let simple = specifier.as(SimpleTypeSpecifierSyntax.self) else {
                    convention = .unsupported
                    break
                }
                switch simple.specifier.tokenKind {
                case .keyword(.borrowing), .identifier("__shared"):
                    convention = .borrowing
                case .keyword(.consuming), .identifier("__owned"):
                    convention = .consuming
                case .keyword(.sending):
                    convention = .sending
                case .keyword(.inout):
                    convention = .inout
                default:
                    convention = .unsupported
                }
            }
            attributed.specifiers = []
            return (TypeSyntax(attributed), convention)
        }
    }
}

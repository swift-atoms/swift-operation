import Type_Algebra_Syntax
public import SwiftSyntax
import SwiftSyntaxBuilder

extension Operation {
    // Symbols describe operations. Input capability conformances belong to their callers,
    // using same-file native extensions; transferring a parameter suppresses Copyable.
    public enum Derivation {
        public static func peers(of analysis: Analysis) -> [DeclSyntax] {
            do { return try derive(analysis) }
            catch { return [DeclSyntax(stringLiteral: "#error(\(String(reflecting: String(describing: error))))")] }
        }

        private static func derive(_ analysis: Analysis) throws -> [DeclSyntax] {
            let access = access(of: analysis.declaration)
            let owner = analysis.owner.trimmedDescription
            return try analysis.algebra.operations.map { operation in
                guard let symbol = analysis.symbols.first(where: { $0.caseName == operation.name }) else {
                    throw Type.Failure("missing Swift representation for operation")
                }
                let call = symbol.isPrimary ? "owner" : "owner.\(symbol.signature.name.text)"
                let conformance = analysis.isComposed ? "Operation::Operation.Operable, Operation::Operation.Composed" : "Operation::Operation.Symbol"
                return DeclSyntax(stringLiteral: """
                    \(access)enum \(symbol.name): \(conformance) {
                        \(access)typealias Owner = \(owner)
                    \(analysis.isComposed ? """
                        \(access)typealias Call = \(owner).Call

                        \(access)static func call(_ input: consuming Input) -> \(owner).Call {
                            .\(symbol.caseName)(input)
                        }
                        \(access)static func input(from call: consuming Call) -> Input? {
                            switch consume call {
                            case let .\(symbol.caseName)(application): return application.consume()
                            \(analysis.symbols.count == 1 && !analysis.declaration.memberBlock.members.contains(where: { $0.decl.is(VariableDeclSyntax.self) }) ? "" : "default: return nil")
                            }
                        }
                    """ : "")
                    \(try input(of: symbol, domain: operation.input, access: access))

                        \(access)typealias Output = \(symbol.output.trimmedDescription)
                        \(access)typealias Failure = \(symbol.failure.trimmedDescription)
                        \(access)typealias Application = Operation::Operation.Application<Self>

                    \(analysis.isComposed ? """
                        \(access)static func run(_ owner: \(owner), _ input: consuming Input)\(symbol.effects) -> Output {
                            \(symbol.signature.returnsVoid ? "" : "return ")\(symbol.prefix)\(call)(input)
                        }
                    """ : "")
                    }
                    """)
            }
        }

        // A one-field input reads as its field: `input.title` is `input.list.title`.
        private static func input(of symbol: Analysis.Symbol, domain: Type.Expression, access: String) throws -> String {
            let forwarding = symbol.inputs.count == 1 && !symbol.transfers
                ? """

                    \(symbol.inputs[0].parameter.localName.text == "fieldValue" ? "" : "\(access)var fieldValue: \(symbol.inputs[0].type.trimmedDescription) { \(symbol.inputs[0].parameter.localName.text) }")

                    \(access)subscript<Member>(dynamicMember keyPath: Swift.KeyPath<\(symbol.inputs[0].type.trimmedDescription), Member>) -> Member {
                        \(symbol.inputs[0].parameter.localName.text)[keyPath: keyPath]
                    }

                    \(access)subscript<Member>(dynamicMember keyPath: Swift.WritableKeyPath<\(symbol.inputs[0].type.trimmedDescription), Member>) -> Member {
                        get { \(symbol.inputs[0].parameter.localName.text)[keyPath: keyPath] }
                        set { \(symbol.inputs[0].parameter.localName.text)[keyPath: keyPath] = newValue }
                    }
                """
                : ""
            let header = symbol.transfers
                ? "\(access)struct Input: ~Copyable {"
                : symbol.inputs.count == 1
                    ? "@dynamicMemberLookup\n\(access)struct Input: Operation::Operation.Unary {"
                    : "\(access)struct Input {"
            guard case .product(let factors) = domain, factors.count == symbol.inputs.count else {
                throw Type.Failure("operation input representation must match its product domain")
            }
            let inputRecord = try Type.Record(zip(symbol.inputs, factors).map { .init($0.parameter.localName.text, $1) })
            let record = try Type.Syntax.Record(inputRecord) { coordinate in
                guard let input = symbol.inputs.first(where: { $0.parameter.localName.text == coordinate.name }) else {
                    throw Type.Failure("missing Swift representation for input")
                }
                let declaration = input.parameter.declaration
                let label = declaration.firstName.tokenKind == .wildcard ? "_" : declaration.firstName.text
                let type = input.type.trimmedDescription
                return .init(input.parameter.localName.text, type: type, label: label,
                    argument: input.parameter.transfersOwnership ? "consuming \(type)" : type)
            }
            let fields = record.declarations(access: access).joined(separator: "\n")
            let initializer = try record.initializer(access: access)
            // A one-field input is also built from its field, whatever the field's label.
            let unary: String
            if symbol.inputs.count == 1, !symbol.transfers,
                symbol.inputs[0].parameter.declaration.firstName.tokenKind != .wildcard
            {
                let local = symbol.inputs[0].parameter.localName.text
                unary = """

                    \(access)init(_ field: \(symbol.inputs[0].type.trimmedDescription)) {
                        self.\(local) = field
                    }
                """
            } else {
                unary = ""
            }
            return """
                \(header)
                \(fields)

                    \(initializer)
                \(unary)\(forwarding)
                }
                """
        }

        public static func access(of declaration: ProtocolDeclSyntax) -> String {
            for modifier in declaration.modifiers {
                switch modifier.name.tokenKind {
                case .keyword(.public), .keyword(.package), .keyword(.fileprivate):
                    return "\(modifier.name.text) "
                case .keyword(.private):
                    return "fileprivate "
                default:
                    continue
                }
            }
            return ""
        }
    }
}

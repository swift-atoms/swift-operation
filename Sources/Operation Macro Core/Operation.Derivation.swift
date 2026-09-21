import Type_Algebra_Syntax
public import SwiftSyntax
import SwiftSyntaxBuilder

extension Operation {
    // Symbols describe operations. Input capability conformances belong to their callers,
    // using native extensions or explicitly forwarded derivation attributes.
    // Transferring a parameter suppresses Copyable.
    public enum Derivation {
        public static func peers(of analysis: Analysis, inputAttributes: [AttributeSyntax] = [], inputConformances: [String] = [], conformances: [String] = [], members: (Analysis.Symbol) -> [DeclSyntax] = { _ in [] }) -> [DeclSyntax] {
            do { return try derive(analysis, inputAttributes: inputAttributes, inputConformances: inputConformances, conformances: conformances, members: members) }
            catch { return [DeclSyntax(stringLiteral: "#error(\(String(reflecting: String(describing: error))))")] }
        }

        private static func derive(_ analysis: Analysis, inputAttributes: [AttributeSyntax], inputConformances: [String], conformances: [String], members: (Analysis.Symbol) -> [DeclSyntax]) throws -> [DeclSyntax] {
            let access = access(of: analysis.declaration)
            let owner = analysis.owner.trimmedDescription
            return try analysis.algebra.operations.map { operation in
                guard let symbol = analysis.symbols.first(where: { $0.caseName == operation.name }) else {
                    throw Type.Failure("missing Swift representation for operation")
                }
                let conformance = (["Operation::Operation.Symbol"] + conformances).joined(separator: ", ")
                return DeclSyntax(stringLiteral: """
                    \(access)enum \(symbol.name): \(conformance) {
                        \(access)typealias Owner = \(owner)
                    \(inputAttributes.map(\.trimmedDescription).joined(separator: "\n"))
                    \(try input(of: symbol, domain: operation.input, access: access, conformances: inputConformances))

                        \(access)typealias Output = \(symbol.output.trimmedDescription)
                        \(access)typealias Failure = \(symbol.failure.trimmedDescription)
                        \(access)typealias Application = Operation::Operation.Application<Self>

                    \(members(symbol).map(\.trimmedDescription).joined(separator: "\n"))
                    }
                    """)
            }
        }

        // A one-field input reads as its field: `input.title` is `input.list.title`.
        private static func input(of symbol: Analysis.Symbol, domain: Type.Expression, access: String, conformances: [String]) throws -> String {
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
            let inherited = (symbol.transfers ? ["~Copyable"] : symbol.inputs.count == 1 ? ["Operation::Operation.Unary"] : []) + conformances
            let header = (!symbol.transfers && symbol.inputs.count == 1 ? "@dynamicMemberLookup\n" : "")
                + "\(access)struct Input" + (inherited.isEmpty ? "" : ": " + inherited.joined(separator: ", ")) + " {"
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

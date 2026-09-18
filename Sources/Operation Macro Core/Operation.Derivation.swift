public import SwiftSyntax
import SwiftSyntaxBuilder

extension Operation {
    // One symbol per operation, beside the protocol: an enum conforming to Operation.Symbol that carries the
    // operation's Input as a value (the parameters, initialised with the declaration's labels), its Output and
    // Failure, and its Application. The Input's capabilities are whatever the compiler synthesizes from its
    // fields: Hashable (an input is a value) and Sendable (declared for convenience — a public type gets no
    // implicit Sendable, and inputs cross into tasks; nothing here relies on it); Copyable is suppressed when a
    // parameter is transferred.
    public enum Derivation {
        public static func peers(of analysis: Analysis) -> [DeclSyntax] {
            let access = access(of: analysis.declaration)
            return analysis.symbols.map { symbol in
                DeclSyntax(stringLiteral: """
                    \(access)enum \(symbol.name): Operation::Operation.Symbol {
                    \(input(of: symbol, access: access))

                        \(access)typealias Output = \(symbol.output.trimmedDescription)
                        \(access)typealias Failure = \(symbol.failure.trimmedDescription)
                        \(access)typealias Application = Operation::Operation.Application<Self>
                    }
                    """)
            }
        }

        private static func input(of symbol: Analysis.Symbol, access: String) -> String {
            let header = symbol.transfers
                ? "\(access)struct Input: ~Copyable, Swift.Sendable {"
                : "\(access)struct Input: Swift.Hashable, Swift.Sendable {"
            let fields = symbol.inputs.map { input in
                "\(access)var \(input.parameter.localName.text): \(input.type.trimmedDescription)"
            }.joined(separator: "\n")
            let parameters = symbol.inputs.map { input in
                let declaration = input.parameter.declaration
                let label = declaration.firstName.tokenKind == .wildcard ? "_" : declaration.firstName.text
                let local = input.parameter.localName.text
                let type = input.type.trimmedDescription
                let spelled = input.parameter.transfersOwnership ? "consuming \(type)" : type
                return label == local ? "\(local): \(spelled)" : "\(label) \(local): \(spelled)"
            }.joined(separator: ", ")
            let assignments = symbol.inputs.map { input in
                "self.\(input.parameter.localName.text) = \(input.parameter.localName.text)"
            }.joined(separator: "\n")
            return """
                \(header)
                \(fields)

                    \(access)init(\(parameters)) {
                    \(assignments)
                    }
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

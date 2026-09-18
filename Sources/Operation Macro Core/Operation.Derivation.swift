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
            let owner = analysis.owner.trimmedDescription
            return analysis.symbols.map { symbol in
                let call = symbol.isPrimary ? "owner" : "owner.\(symbol.signature.name.text)"
                let composed = analysis.isComposed ? ", Operation::Operation.Composed" : ""
                return DeclSyntax(stringLiteral: """
                    \(access)enum \(symbol.name): Operation::Operation.Operable\(composed) {
                        \(access)typealias Owner = \(owner)
                    \(analysis.isComposed ? """
                        \(access)typealias Call = \(owner).Call

                        \(access)static func call(_ input: consuming Input) -> \(owner).Call {
                            .\(symbol.caseName)(input)
                        }
                    """ : "")
                    \(input(of: symbol, access: access))

                        \(access)typealias Output = \(symbol.output.trimmedDescription)
                        \(access)typealias Failure = \(symbol.failure.trimmedDescription)
                        \(access)typealias Application = Operation::Operation.Application<Self>

                        \(access)static func run(_ owner: \(owner), _ input: consuming Input)\(symbol.effects) -> Output {
                            \(symbol.signature.returnsVoid ? "" : "return ")\(symbol.prefix)\(call)(input)
                        }
                    }
                    """)
            }
        }

        // A one-field input reads as its field: `input.title` is `input.list.title`.
        private static func input(of symbol: Analysis.Symbol, access: String) -> String {
            let forwarding = symbol.inputs.count == 1 && !symbol.transfers
                ? """

                    \(access)subscript<Member>(dynamicMember keyPath: Swift.WritableKeyPath<\(symbol.inputs[0].type.trimmedDescription), Member>) -> Member {
                        get { \(symbol.inputs[0].parameter.localName.text)[keyPath: keyPath] }
                        set { \(symbol.inputs[0].parameter.localName.text)[keyPath: keyPath] = newValue }
                    }
                """
                : ""
            let header = symbol.transfers
                ? "\(access)struct Input: ~Copyable, Swift.Sendable {"
                : symbol.inputs.count == 1
                    ? "@dynamicMemberLookup\n\(access)struct Input: Swift.Hashable, Swift.Sendable {"
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
                \(forwarding)
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

import Operation_Macro_Core
import SwiftSyntax
import SwiftSyntaxMacros

public struct Macro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let declaration = declaration.as(ProtocolDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("@Operations applies to a protocol declaration only.")
        }
        let composition = node.arguments?.as(LabeledExprListSyntax.self)?.first(where: { $0.label?.text == "composed" })?.expression.trimmedDescription
        guard composition == nil || composition == "true" || composition == "false" else {
            throw MacroExpansionErrorMessage("@Operations composed must be a literal Boolean.")
        }
        let isComposed = composition == "true"
        let owner = context.lexicalContext.first.flatMap { syntax -> TypeSyntax? in
            if let declaration = syntax.as(EnumDeclSyntax.self) {
                return TypeSyntax(IdentifierTypeSyntax(name: declaration.name.trimmed))
            }
            if let declaration = syntax.as(StructDeclSyntax.self) {
                return TypeSyntax(IdentifierTypeSyntax(name: declaration.name.trimmed))
            }
            if let declaration = syntax.as(ExtensionDeclSyntax.self) {
                return declaration.extendedType.trimmed
            }
            return nil
        }
        guard let owner else {
            throw MacroExpansionErrorMessage("@Operations applies to a protocol nested in the type that will hold its symbols.")
        }
        let analysis = Operation.Analysis(declaration: declaration, owner: owner, isComposed: isComposed)
        guard analysis.diagnostics.isEmpty else {
            throw MacroExpansionErrorMessage(
                "@Operations cannot read every operation: \(analysis.diagnostics.joined(separator: "; "))."
            )
        }
        return Operation.Derivation.peers(of: analysis)
    }
}

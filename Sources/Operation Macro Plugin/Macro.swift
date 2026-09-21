import Operation_Macro_Core
import SwiftSyntax
import SwiftSyntaxBuilder
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
        let analysis = Operation.Analysis(declaration: declaration, owner: owner)
        guard analysis.diagnostics.isEmpty else {
            throw MacroExpansionErrorMessage(
                "@Operations cannot read every operation: \(analysis.diagnostics.joined(separator: "; "))."
            )
        }
        let input = try Operation.Derivation.Input(node)
        return Operation.Derivation.peers(of: analysis, inputAttributes: input.attributes, inputConformances: input.conformances)
    }
}

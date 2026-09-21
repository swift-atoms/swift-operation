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
        var conformances: [String] = []
        if let argument = node.arguments?.as(LabeledExprListSyntax.self)?.first(where: { $0.label?.text == "inputConformances" }) {
            guard let array = argument.expression.as(ArrayExprSyntax.self) else {
                throw MacroExpansionErrorMessage("inputConformances requires an array of literal protocol names")
            }
            for element in array.elements {
                guard let literal = element.expression.as(StringLiteralExprSyntax.self), literal.segments.count == 1,
                    let segment = literal.segments.first?.as(StringSegmentSyntax.self) else {
                    throw MacroExpansionErrorMessage("inputConformances requires literal protocol names")
                }
                let parsed = TypeSyntax(stringLiteral: segment.content.text)
                guard !parsed.hasError, parsed.is(IdentifierTypeSyntax.self) || parsed.is(MemberTypeSyntax.self) else {
                    throw MacroExpansionErrorMessage("inputConformances requires protocol type names")
                }
                conformances.append(parsed.trimmedDescription)
            }
        }
        var attributes: [AttributeSyntax] = []
        var readingAttributes = false
        for argument in node.arguments?.as(LabeledExprListSyntax.self) ?? [] {
            if argument.label?.text == "inputAttributes" { readingAttributes = true }
            guard readingAttributes else { continue }
            guard let literal = argument.expression.as(StringLiteralExprSyntax.self),
                literal.segments.count == 1,
                let segment = literal.segments.first?.as(StringSegmentSyntax.self) else {
                throw MacroExpansionErrorMessage("inputAttributes requires literal attribute strings without interpolation")
            }
            let parsed = DeclSyntax(stringLiteral: segment.content.text + "\nstruct _Input {}")
            guard !parsed.hasError, let structure = parsed.as(StructDeclSyntax.self),
                structure.name.text == "_Input", structure.memberBlock.members.isEmpty,
                structure.modifiers.isEmpty, !structure.attributes.isEmpty,
                structure.attributes.allSatisfy({ $0.is(AttributeSyntax.self) }) else {
                throw MacroExpansionErrorMessage("inputAttributes accepts only attributes, for example \"@Finite\"")
            }
            attributes += structure.attributes.compactMap { $0.as(AttributeSyntax.self) }
        }
        return Operation.Derivation.peers(of: analysis, inputAttributes: attributes, inputConformances: conformances)
    }
}

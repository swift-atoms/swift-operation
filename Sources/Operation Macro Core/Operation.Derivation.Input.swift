import Type_Algebra_Syntax
public import SwiftSyntax
import SwiftSyntaxBuilder

extension Operation.Derivation {
    /// Explicit capabilities forwarded to generated inputs; no shape inference.
    public struct Input {
        public let attributes: [AttributeSyntax]
        public let conformances: [String]
        public init(_ node: AttributeSyntax) throws {
        var conformances: [String] = []
        if let argument = node.arguments?.as(LabeledExprListSyntax.self)?.first(where: { $0.label?.text == "inputConformances" }) {
            guard let array = argument.expression.as(ArrayExprSyntax.self) else {
                throw Type.Failure("inputConformances requires an array of literal protocol names")
            }
            for element in array.elements {
                guard let literal = element.expression.as(StringLiteralExprSyntax.self), literal.segments.count == 1,
                    let segment = literal.segments.first?.as(StringSegmentSyntax.self) else {
                    throw Type.Failure("inputConformances requires literal protocol names")
                }
                let parsed = TypeSyntax(stringLiteral: segment.content.text)
                guard !parsed.hasError, parsed.is(IdentifierTypeSyntax.self) || parsed.is(MemberTypeSyntax.self) else {
                    throw Type.Failure("inputConformances requires protocol type names")
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
                throw Type.Failure("inputAttributes requires literal attribute strings without interpolation")
            }
            let parsed = DeclSyntax(stringLiteral: segment.content.text + "\nstruct _Input {}")
            guard !parsed.hasError, let structure = parsed.as(StructDeclSyntax.self),
                structure.name.text == "_Input", structure.memberBlock.members.isEmpty,
                structure.modifiers.isEmpty, !structure.attributes.isEmpty,
                structure.attributes.allSatisfy({ $0.is(AttributeSyntax.self) }) else {
                throw Type.Failure("inputAttributes accepts only attributes, for example \"@Finite\"")
            }
            attributes += structure.attributes.compactMap { $0.as(AttributeSyntax.self) }
        }
            self.attributes = attributes
            self.conformances = conformances
        }
    }
}

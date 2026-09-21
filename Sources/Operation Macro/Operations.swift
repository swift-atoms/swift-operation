@_exported import Operation

// Every function of the protocol becomes a symbol beside it — `Owner.Greet: Operation.Symbol` with the
// function's parameters as `Input`, its result as `Output`, its thrown error as `Failure`. The protocol must be
// nested in the type that holds the symbols; that type's name qualifies them.
/// Attributes explicitly forwarded to each generated Input declaration.
/// The operation macro does not interpret or implement those capabilities.
@attached(peer, names: arbitrary)
public macro Operations(inputConformances: [String] = [], inputAttributes: String...) = #externalMacro(
    module: "Operation_Macro_Plugin",
    type: "Macro"
)

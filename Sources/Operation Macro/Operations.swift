@_exported import Operation

@attached(peer, names: arbitrary)
public macro Operations(inputConformances: [String] = [], inputAttributes: String...) = #externalMacro(
    module: "Operation_Macro_Plugin",
    type: "Macro"
)

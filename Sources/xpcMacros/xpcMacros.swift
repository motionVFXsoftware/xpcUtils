import Foundation

@attached(body)
public macro checkInit() = #externalMacro(module: "xpcMacrosMacros", type: "CheckInitMacro")

@attached(peer, names: suffixed(Client))
public macro GenerateCodableClient() = #externalMacro(
    module: "xpcMacrosMacros",
    type: "GenerateCodableClientMacro"
)

@attached(peer, names: suffixed(Server))
public macro GenerateCodableServer() = #externalMacro(
    module: "xpcMacrosMacros",
    type: "GenerateCodableServerMacro"
)

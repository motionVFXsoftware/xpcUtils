import Foundation

@attached(body)
public macro checkInit() = #externalMacro(module: "xpcMacrosMacros", type: "CheckInitMacro")

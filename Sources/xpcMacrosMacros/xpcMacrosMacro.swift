import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CheckInitMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {

        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.notAFunction
        }

        guard let originalBody = funcDecl.body else {
            throw MacroError.noFunctionBody
        }

        var newStatements: [CodeBlockItemSyntax] = []

        let initCheck = CodeBlockItemSyntax(
            item: .stmt(StmtSyntax(
                "if !self.isInitialized { throw WhisperXPCError.whisperNotInitialized }"
            ))
        )
        newStatements.append(initCheck)

        newStatements.append(contentsOf: originalBody.statements)

        return newStatements
    }
}

enum MacroError: Error, CustomStringConvertible {
    case notAFunction
    case noFunctionBody

    var description: String {
        switch self {
        case .notAFunction:
            return "@checkInit can only be applied to functions"
        case .noFunctionBody:
            return "@checkInit requires a function with a body"
        }
    }
}

@main
struct xpcMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CheckInitMacro.self,
    ]
}

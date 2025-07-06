
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

        // Create initialization check using IfExprSyntax
        let initCheck = CodeBlockItemSyntax(
            item: .stmt(
                StmtSyntax(
                    ExpressionStmtSyntax(
                        expression: IfExprSyntax(
                            conditions: ConditionElementListSyntax([
                                ConditionElementSyntax(
                                    condition: .expression(
                                        ExprSyntax(
                                            PrefixOperatorExprSyntax(
                                                operator: .prefixOperator("!"),
                                                expression: MemberAccessExprSyntax(
                                                    base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                                                    period: .periodToken(),
                                                    name: .identifier("isInitialized")
                                                )
                                            )
                                        )
                                    )
                                )
                            ]),
                            body: CodeBlockSyntax(
                                statements: CodeBlockItemListSyntax([
                                    CodeBlockItemSyntax(
                                        item: .stmt(
                                            StmtSyntax(
                                                ThrowStmtSyntax(
                                                    expression: MemberAccessExprSyntax(
                                                        base: DeclReferenceExprSyntax(baseName: .identifier("WhisperXPCError")),
                                                        period: .periodToken(),
                                                        name: .identifier("whisperNotInitialized")
                                                    )
                                                )
                                            )
                                        )
                                    )
                                ])
                            )
                        )
                    )
                )
            )
        )
        newStatements.append(initCheck)
        newStatements.append(contentsOf: originalBody.statements)

        return newStatements
    }
}

class ProtocolVariableVisitor: SyntaxVisitor {
    var variables: [(name: String, type: TypeSyntax)] = []

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            if let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
               let typeAnnotation = binding.typeAnnotation {
                let name = identifier.identifier.text
                let type = typeAnnotation.type.trimmed
                variables.append((name: name, type: type))
            }
        }
        return .visitChildren
    }
}

class ProtocolMethodVisitor: SyntaxVisitor {
    var methods: [FunctionDeclSyntax] = []

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        methods.append(node)
        return .visitChildren
    }
}

public struct GenerateCodableClientMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
            throw MacroError.notAProtocol
        }

        let protocolName = proto.name.text
        let structName = "\(protocolName)Client"

        // Extract properties and methods using visitors
        let propertyVisitor = ProtocolVariableVisitor(viewMode: .all)
        let methodVisitor = ProtocolMethodVisitor(viewMode: .all)

        propertyVisitor.walk(proto)
        methodVisitor.walk(proto)

        // Generate the struct declaration
        let structDecl = createStructDeclaration(
            name: structName,
            protocolName: protocolName,
            properties: propertyVisitor.variables,
            methods: methodVisitor.methods
        )

        return [DeclSyntax(structDecl)]
    }

    private static func createStructDeclaration(
        name: String,
        protocolName: String,
        properties: [(name: String, type: TypeSyntax)],
        methods: [FunctionDeclSyntax]
    ) -> StructDeclSyntax {

        var members: [MemberBlockItemSyntax] = []

        // Add private connection property
        let connectionProperty = VariableDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.private))
            ]),
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("connection")),
                    typeAnnotation: TypeAnnotationSyntax(
                        type: IdentifierTypeSyntax(name: .identifier("XPCConnection"))
                    )
                )
            ])
        )
        members.append(MemberBlockItemSyntax(decl: connectionProperty))

        // Add protocol properties
        for property in properties {
            let propertyDecl = VariableDeclSyntax(
                modifiers: DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(.public))
                ]),
                bindingSpecifier: .keyword(.var),
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: .identifier(property.name)),
                        typeAnnotation: TypeAnnotationSyntax(type: property.type)
                    )
                ])
            )
            members.append(MemberBlockItemSyntax(decl: propertyDecl))
        }

        // Add initializer
        let initializer = createInitializer(properties: properties)
        members.append(MemberBlockItemSyntax(decl: initializer))

        // Add method stubs
        for method in methods {
            let methodStub = createMethodStub(from: method)
            members.append(MemberBlockItemSyntax(decl: methodStub))
        }

        return StructDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public))
            ]),
            name: .identifier(name),
            inheritanceClause: InheritanceClauseSyntax(
                inheritedTypes: InheritedTypeListSyntax([
                    InheritedTypeSyntax(
                        type: IdentifierTypeSyntax(name: .identifier(protocolName))
                    )
                ])
            ),
            memberBlock: MemberBlockSyntax(
                members: MemberBlockItemListSyntax(members)
            )
        )
    }

    private static func createInitializer(properties: [(name: String, type: TypeSyntax)]) -> InitializerDeclSyntax {
        // Create connection parameter
        let connectionParam = FunctionParameterSyntax(
            firstName: .identifier("connection"),
            type: IdentifierTypeSyntax(name: .identifier("XPCConnection"))
        )

        // Create parameters for each property using FunctionParameterSyntax
        let propertyParams = properties.map { property in
            FunctionParameterSyntax(
                firstName: .identifier(property.name),
                type: property.type
            )
        }

        var allParams: [FunctionParameterSyntax] = [connectionParam]
        allParams.append(contentsOf: propertyParams)

        let parameterList = FunctionParameterListSyntax(
            allParams.enumerated().map { index, param in
                if index < allParams.count - 1 {
                    return param.with(\.trailingComma, .commaToken())
                } else {
                    return param
                }
            }
        )

        // Create assignment expressions using AssignmentExprSyntax
        let connectionAssignment = ExprSyntax(
            SequenceExprSyntax {
                MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                    period: .periodToken(),
                    name: .identifier("connection")
                )
                AssignmentExprSyntax()
                DeclReferenceExprSyntax(baseName: .identifier("connection"))
            }
        )

        let propertyAssignments = properties.map { property in
            ExprSyntax(
                SequenceExprSyntax {
                    MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                        period: .periodToken(),
                        name: .identifier(property.name)
                    )
                    AssignmentExprSyntax()
                    DeclReferenceExprSyntax(baseName: .identifier(property.name))
                }
            )
        }

        var allAssignments = [connectionAssignment]
        allAssignments.append(contentsOf: propertyAssignments)

        return InitializerDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public))
            ]),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(),
                    parameters: parameterList,
                    rightParen: .rightParenToken()
                )
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax(
                    allAssignments.map { CodeBlockItemSyntax(item: .expr($0)) }
                )
            )
        )
    }

    private static func createMethodStub(from method: FunctionDeclSyntax) -> FunctionDeclSyntax {
        let methodName = method.name.text

        let parameters = method.signature.parameterClause.parameters.enumerated().map { index, param in
            let isLast = index == method.signature.parameterClause.parameters.count - 1
            return FunctionParameterSyntax(
                firstName: param.firstName,
                secondName: param.secondName,
                type: param.type,
                trailingComma: isLast ? nil : .commaToken()
            )
        }

        // Create the sendMessage call
        let sendMessageCall = createSendMessageCall(
            methodName: methodName,
            parameters: Array(method.signature.parameterClause.parameters),
            returnType: method.signature.returnClause?.type
        )

        // Create method signature with async throws (handling deprecation)
        var effectSpecifiers = method.signature.effectSpecifiers ?? FunctionEffectSpecifiersSyntax()

        if effectSpecifiers.asyncSpecifier == nil {
            effectSpecifiers = effectSpecifiers.with(\.asyncSpecifier, .keyword(.async))
        }

        // Handle the deprecated throwsSpecifier
        if effectSpecifiers.throwsClause == nil {
            effectSpecifiers = effectSpecifiers.with(\.throwsClause,
                ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
            )
        }

        return FunctionDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public))
            ]),
            name: method.name,
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(),
                    parameters: FunctionParameterListSyntax(parameters),
                    rightParen: .rightParenToken()
                ),
                effectSpecifiers: effectSpecifiers,
                returnClause: method.signature.returnClause
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .stmt(sendMessageCall))
                ])
            )
        )
    }

    private static func createSendMessageCall(
        methodName: String,
        parameters: [FunctionParameterSyntax],
        returnType: TypeSyntax?
    ) -> StmtSyntax {

        // Create the base arguments list with just the name parameter
        var arguments = [
            LabeledExprSyntax(
                label: .identifier("name"),
                colon: .colonToken(),
                expression: StringLiteralExprSyntax(
                    content: methodName
                )
            )
        ]

        // Only add request parameter if there are parameters to send
        if !parameters.isEmpty {
            let requestExpr = createRequestExpression(from: parameters)

            // Add comma to the name parameter
            arguments[0] = arguments[0].with(\.trailingComma, .commaToken())

            // Add request parameter
            arguments.append(
                LabeledExprSyntax(
                    label: .identifier("request"),
                    colon: .colonToken(),
                    expression: requestExpr
                )
            )
        }

        // Create the sendMessage function call
        let sendMessageExpr = FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("connection")),
                period: .periodToken(),
                name: .identifier("sendMessage")
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(arguments),
            rightParen: .rightParenToken()
        )

        // Handle return type
        if let returnType = returnType,
           returnType.trimmedDescription != "Void" {
            // For non-Void returns, use return try await
            return StmtSyntax(
                ReturnStmtSyntax(
                    expression: TryExprSyntax(
                        expression: AwaitExprSyntax(
                            expression: sendMessageExpr
                        )
                    )
                )
            )
        } else {
            // For Void returns, use try await without return
            return StmtSyntax(
                ExpressionStmtSyntax(
                    expression: TryExprSyntax(
                        expression: AwaitExprSyntax(
                            expression: sendMessageExpr
                        )
                    )
                )
            )
        }
    }

    private static func createRequestExpression(from parameters: [FunctionParameterSyntax]) -> ExprSyntax {
        if parameters.count == 1 {
            // Single parameter - pass it directly
            let param = parameters[0]
            let paramName = param.secondName?.text ?? param.firstName.text
            return ExprSyntax(
                DeclReferenceExprSyntax(baseName: .identifier(paramName))
            )
        } else {
            // Multiple parameters - create a tuple
            let tupleElements = parameters.enumerated().map { index, param in
                let paramName = param.secondName?.text ?? param.firstName.text
                let isLast = index == parameters.count - 1

                return LabeledExprSyntax(
                    expression: DeclReferenceExprSyntax(baseName: .identifier(paramName)),
                    trailingComma: isLast ? nil : .commaToken()
                )
            }

            return ExprSyntax(
                TupleExprSyntax(
                    leftParen: .leftParenToken(),
                    elements: LabeledExprListSyntax(tupleElements),
                    rightParen: .rightParenToken()
                )
            )
        }
    }
}

enum MacroError: Error, CustomStringConvertible {
    case notAFunction
    case noFunctionBody
    case notAProtocol

    var description: String {
        switch self {
        case .notAFunction:
            return "macro can only be applied to functions"
        case .noFunctionBody:
            return "macro requires a function with a body"
        case .notAProtocol:
            return "macro requires a protocol"
        }
    }
}

public struct GenerateCodableServerMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
            throw MacroError.notAProtocol
        }

        let protocolName = proto.name.text
        let className = "\(protocolName)Server"

        // Extract properties and methods using visitors
        let propertyVisitor = ProtocolVariableVisitor(viewMode: .all)
        let methodVisitor = ProtocolMethodVisitor(viewMode: .all)

        propertyVisitor.walk(proto)
        methodVisitor.walk(proto)

        // Generate the class declaration
        let classDecl = createServerClassDeclaration(
            name: className,
            protocolName: protocolName,
            properties: propertyVisitor.variables,
            methods: methodVisitor.methods
        )

        return [DeclSyntax(classDecl)]
    }

    private static func createServerClassDeclaration(
        name: String,
        protocolName: String,
        properties: [(name: String, type: TypeSyntax)],
        methods: [FunctionDeclSyntax]
    ) -> ClassDeclSyntax {

        var members: [MemberBlockItemSyntax] = []

        // Add private listener property
        let listenerProperty = VariableDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public))
            ]),
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("listener")),
                    typeAnnotation: TypeAnnotationSyntax(
                        type: IdentifierTypeSyntax(name: .identifier("SwiftyXPC.XPCListener"))
                    )
                )
            ])
        )
        members.append(MemberBlockItemSyntax(decl: listenerProperty))

        // Add protocol properties
        for property in properties {
            let propertyDecl = VariableDeclSyntax(
                modifiers: DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(.public))
                ]),
                bindingSpecifier: .keyword(.var),
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: .identifier(property.name)),
                        typeAnnotation: TypeAnnotationSyntax(type: property.type)
                    )
                ])
            )
            members.append(MemberBlockItemSyntax(decl: propertyDecl))
        }

        // Add initializer
        let initializer = createServerInitializer(properties: properties)
        members.append(MemberBlockItemSyntax(decl: initializer))

        // Add method stubs (fatalError implementations)
        for method in methods {
            let methodStub = createServerMethodStub(from: method)
            members.append(MemberBlockItemSyntax(decl: methodStub))
        }

        // Add initListener method
        let initListenerMethod = createInitListenerMethod(methods: methods)
        members.append(MemberBlockItemSyntax(decl: initListenerMethod))

        return ClassDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.open))
            ]),
            name: .identifier(name),
            inheritanceClause: InheritanceClauseSyntax(
                inheritedTypes: InheritedTypeListSyntax([
                    InheritedTypeSyntax(
                        type: IdentifierTypeSyntax(name: .identifier("@unchecked Sendable"))
                    )
                ])
            ),
            memberBlock: MemberBlockSyntax(
                members: MemberBlockItemListSyntax(members)
            )
        )
    }

    private static func createServerInitializer(properties: [(name: String, type: TypeSyntax)]) -> InitializerDeclSyntax {
        // Create listener parameter
        let listenerParam = FunctionParameterSyntax(
            firstName: .identifier("listener"),
            type: IdentifierTypeSyntax(name: .identifier("SwiftyXPC.XPCListener"))
        )

        // Create parameters for each property using FunctionParameterSyntax
        let propertyParams = properties.map { property in
            FunctionParameterSyntax(
                firstName: .identifier(property.name),
                type: property.type
            )
        }

        // Combine all parameters with proper comma handling
        var allParams: [FunctionParameterSyntax] = [listenerParam]
        allParams.append(contentsOf: propertyParams)

        // Create parameter list with proper comma separators
        let parameterList = FunctionParameterListSyntax(
            allParams.enumerated().map { index, param in
                // Add trailing comma for all parameters except the last one
                if index < allParams.count - 1 {
                    return param.with(\.trailingComma, .commaToken())
                } else {
                    return param
                }
            }
        )

        // Create assignment expressions using AssignmentExprSyntax
        let listenerAssignment = ExprSyntax(
            SequenceExprSyntax {
                MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                    period: .periodToken(),
                    name: .identifier("listener")
                )
                AssignmentExprSyntax()
                DeclReferenceExprSyntax(baseName: .identifier("listener"))
            }
        )

        let propertyAssignments = properties.map { property in
            ExprSyntax(
                SequenceExprSyntax {
                    MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                        period: .periodToken(),
                        name: .identifier(property.name)
                    )
                    AssignmentExprSyntax()
                    DeclReferenceExprSyntax(baseName: .identifier(property.name))
                }
            )
        }

        var allAssignments = [listenerAssignment]
        allAssignments.append(contentsOf: propertyAssignments)

        return InitializerDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public))
            ]),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(),
                    parameters: parameterList,
                    rightParen: .rightParenToken()
                )
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax(
                    allAssignments.map { CodeBlockItemSyntax(item: .expr($0)) }
                )
            )
        )
    }

    private static func createServerMethodStub(from method: FunctionDeclSyntax) -> FunctionDeclSyntax {
        let methodName = method.name.text

        // Create connection parameter as first parameter
        let connectionParam = FunctionParameterSyntax(
            firstName: .identifier("_"),
            secondName: .identifier("connection"),
            type: IdentifierTypeSyntax(name: .identifier("XPCConnection"))
        )

        // Extract original parameters with proper external/internal name handling
        let originalParameters = method.signature.parameterClause.parameters.map { param in
            FunctionParameterSyntax(
                firstName: param.firstName,
                secondName: param.secondName,
                type: param.type
            )
        }

        // Combine connection parameter with original parameters
        var allParameters = [connectionParam]
        allParameters.append(contentsOf: originalParameters)

        // Create parameter list with proper comma handling
        let parameterList = FunctionParameterListSyntax(
            allParameters.enumerated().map { index, param in
                if index < allParameters.count - 1 {
                    return param.with(\.trailingComma, .commaToken())
                } else {
                    return param
                }
            }
        )

        // Create fatalError call for server methods
        let fatalErrorCall = ExprSyntax(
            FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("fatalError")),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax([
                    LabeledExprSyntax(
                        expression: StringLiteralExprSyntax(
                            content: "not implemented \(methodName)"
                        )
                    )
                ]),
                rightParen: .rightParenToken()
            )
        )

        // Create method signature with async throws (handling deprecation)
        var effectSpecifiers = method.signature.effectSpecifiers ?? FunctionEffectSpecifiersSyntax()

        if effectSpecifiers.asyncSpecifier == nil {
            effectSpecifiers = effectSpecifiers.with(\.asyncSpecifier, .keyword(.async))
        }

        // Handle the deprecated throwsSpecifier
        if effectSpecifiers.throwsClause == nil {
            effectSpecifiers = effectSpecifiers.with(\.throwsClause,
                ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
            )
        }

        return FunctionDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.open))
            ]),
            name: method.name,
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(),
                    parameters: parameterList,
                    rightParen: .rightParenToken()
                ),
                effectSpecifiers: effectSpecifiers,
                returnClause: method.signature.returnClause
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(fatalErrorCall))
                ])
            )
        )
    }

    private static func createInitListenerMethod(methods: [FunctionDeclSyntax]) -> FunctionDeclSyntax {
        // Create setMessageHandler calls for each method
        let handlerCalls = methods.map { method in
            let methodName = method.name.text

            let setHandlerCall = ExprSyntax(
                FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: .identifier("listener")),
                        period: .periodToken(),
                        name: .identifier("setMessageHandler")
                    ),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax([
                        LabeledExprSyntax(
                            label: .identifier("name"),
                            colon: .colonToken(),
                            expression: StringLiteralExprSyntax(
                                content: methodName
                            ),
                            trailingComma: .commaToken()
                        ),
                        LabeledExprSyntax(
                            label: .identifier("handler"),
                            colon: .colonToken(),
                            expression: DeclReferenceExprSyntax(baseName: .identifier(methodName))
                        )
                    ]),
                    rightParen: .rightParenToken()
                )
            )

            return CodeBlockItemSyntax(item: .expr(setHandlerCall))
        }

        return FunctionDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public))
            ]),
            name: .identifier("initListener"),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(),
                    parameters: FunctionParameterListSyntax([]),
                    rightParen: .rightParenToken()
                )
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax(handlerCalls)
            )
        )
    }
}

@main
struct xpcMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CheckInitMacro.self,
        GenerateCodableClientMacro.self,
        GenerateCodableServerMacro.self
    ]
}

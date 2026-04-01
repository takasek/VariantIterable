import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - VariantPeerMacro

/// Marker only. All code generation is handled by `VariantIterableMacro`.
public struct VariantPeerMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}

// MARK: - VariantIterableMacro

public struct VariantIterableMacro: MemberMacro, ExtensionMacro {

    // MARK: MemberMacro – generates allVariants

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let entries = collectEntries(from: declaration, in: context)
        let access = accessModifier(of: declaration)

        let body = entries
            .map { #"        (name: "\#($0.name)", value: \#($0.callExpr)),"# }
            .joined(separator: "\n")

        let generated: DeclSyntax = """
        \(raw: access)static var allVariants: [(name: String, value: Self)] {
            [
        \(raw: body)
            ]
        }
        """
        return [generated]
    }

    // MARK: ExtensionMacro – adds VariantIterable conformance

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let ext: DeclSyntax = "extension \(type.trimmed): VariantIterable {}"
        return [ext.cast(ExtensionDeclSyntax.self)]
    }

    // MARK: - Entry Collection

    private static func collectEntries(
        from declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) -> [(name: String, callExpr: String)] {
        var entries: [(name: String, callExpr: String)] = []

        for item in declaration.memberBlock.members {
            let decl = item.decl

            // 1. enum case
            if let caseDecl = decl.as(EnumCaseDeclSyntax.self) {
                let annotations = caseDecl.attributes.variantAnnotations()
                guard !annotations.isEmpty else { continue }

                if caseDecl.elements.count > 1 {
                    context.diagnose(Diagnostic(
                        node: Syntax(caseDecl),
                        message: VariantDiagnostic.multiElementCaseWithAnnotation
                    ))
                    continue
                }

                guard let element = caseDecl.elements.first else { continue }
                let caseName = element.name.text
                let params = element.parameterClause?.parameters ?? []

                for annotation in annotations {
                    let name = annotation.name ?? caseName

                    if let memberRef = annotation.memberRef {
                        entries.append((name: name, callExpr: ".\(memberRef)"))
                        continue
                    }

                    guard annotation.extraArgs.count == params.count else {
                        context.diagnose(Diagnostic(
                            node: Syntax(element),
                            message: VariantDiagnostic.argCountMismatch(
                                name: caseName,
                                expected: params.count,
                                actual: annotation.extraArgs.count
                            )
                        ))
                        continue
                    }

                    if params.isEmpty {
                        entries.append((name: name, callExpr: ".\(caseName)"))
                    } else {
                        let labels = params.map { $0.firstName.flatMap { $0.text == "_" ? nil : $0.text } }
                        let avArgs = buildCallArgs(labels: labels, values: annotation.extraArgs)
                        entries.append((name: name, callExpr: ".\(caseName)(\(avArgs))"))
                    }
                }

            // 2. static let / var
            } else if let varDecl = decl.as(VariableDeclSyntax.self), isStatic(varDecl.modifiers) {
                let annotations = varDecl.attributes.variantAnnotations()
                guard !annotations.isEmpty else { continue }

                guard let memberName = varDecl.bindings.first?
                    .pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                else { continue }

                for annotation in annotations {
                    if !annotation.extraArgs.isEmpty {
                        context.diagnose(Diagnostic(
                            node: Syntax(varDecl),
                            message: VariantDiagnostic.unexpectedArgsOnStoredProperty(name: memberName)
                        ))
                        continue
                    }
                    let name = annotation.name ?? memberName
                    entries.append((name: name, callExpr: ".\(memberName)"))
                }

            // 3. static func
            } else if let funcDecl = decl.as(FunctionDeclSyntax.self), isStatic(funcDecl.modifiers) {
                let annotations = funcDecl.attributes.variantAnnotations()
                guard !annotations.isEmpty else { continue }

                let funcName = funcDecl.name.text
                let params = funcDecl.signature.parameterClause.parameters

                for annotation in annotations {
                    let name = annotation.name ?? funcName

                    guard annotation.extraArgs.count == params.count else {
                        context.diagnose(Diagnostic(
                            node: Syntax(funcDecl),
                            message: VariantDiagnostic.argCountMismatch(
                                name: funcName,
                                expected: params.count,
                                actual: annotation.extraArgs.count
                            )
                        ))
                        continue
                    }

                    if params.isEmpty {
                        entries.append((name: name, callExpr: ".\(funcName)()"))
                    } else {
                        let labels = params.map { $0.firstName.text == "_" ? nil : $0.firstName.text as String? }
                        let callArgs = buildCallArgs(labels: labels, values: annotation.extraArgs)
                        entries.append((name: name, callExpr: ".\(funcName)(\(callArgs))"))
                    }
                }
            }
        }

        return entries
    }

    // MARK: - Helpers

    private static func isStatic(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.tokenKind == .keyword(.static) }
    }

    private static func buildCallArgs(labels: [String?], values: [String]) -> String {
        zip(labels, values)
            .map { label, val in label.map { "\($0): \(val)" } ?? val }
            .joined(separator: ", ")
    }

    private static func accessModifier(of declaration: some DeclGroupSyntax) -> String {
        for mod in declaration.modifiers {
            switch mod.name.tokenKind {
            case .keyword(.public), .keyword(.open): return "public "
            case .keyword(.package):                 return "package "
            case .keyword(.fileprivate):             return "fileprivate "
            case .keyword(.private):                 return "private "
            default: continue
            }
        }
        return ""
    }
}

// MARK: - VariantAnnotation

private struct VariantAnnotation {
    let name: String?
    /// Non-nil when `@Variant(member: "memberName")` is used.
    let memberRef: String?
    /// Positional argument expressions (source text) for `@Variant(arg1, arg2, ...)`.
    let extraArgs: [String]
}

private extension AttributeListSyntax {
    func variantAnnotations() -> [VariantAnnotation] {
        compactMap { element -> VariantAnnotation? in
            guard case .attribute(let attr) = element,
                  attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "Variant"
            else { return nil }

            guard let args = attr.arguments,
                  case .argumentList(let argList) = args
            else {
                // @Variant with no parentheses
                return VariantAnnotation(name: nil, memberRef: nil, extraArgs: [])
            }

            var name: String? = nil
            var memberRef: String? = nil
            var extraArgs: [String] = []

            for arg in argList {
                switch arg.label?.text {
                case "name":   name = extractStringLiteral(from: arg.expression)
                case "member": memberRef = extractStringLiteral(from: arg.expression)
                case nil:      extraArgs.append(arg.expression.trimmedDescription)
                default:       break
                }
            }

            if memberRef != nil {
                return VariantAnnotation(name: name, memberRef: memberRef, extraArgs: [])
            }
            return VariantAnnotation(name: name, memberRef: nil, extraArgs: extraArgs)
        }
    }
}

// MARK: - String Literal Extraction

private func extractStringLiteral(from expr: ExprSyntax?) -> String? {
    guard let expr,
          let strLit = expr.as(StringLiteralExprSyntax.self),
          strLit.segments.allSatisfy({ $0.is(StringSegmentSyntax.self) })
    else { return nil }
    let value = strLit.segments
        .compactMap { $0.as(StringSegmentSyntax.self)?.content.text }
        .joined()
    return value.isEmpty ? nil : value
}

// MARK: - Diagnostics

private enum VariantDiagnostic: DiagnosticMessage {
    case argCountMismatch(name: String, expected: Int, actual: Int)
    case multiElementCaseWithAnnotation
    case unexpectedArgsOnStoredProperty(name: String)

    var message: String {
        switch self {
        case let .argCountMismatch(name, expected, actual):
            return "@Variant: '\(name)' expects \(expected) argument(s) but \(actual) were provided."
        case .multiElementCaseWithAnnotation:
            return "@Variant cannot be applied to a multi-element case declaration (e.g. `case a, b`). Declare each case on its own line."
        case let .unexpectedArgsOnStoredProperty(name):
            return "@Variant: '\(name)' is a stored property; positional arguments are not allowed."
        }
    }

    var diagnosticID: MessageID {
        switch self {
        case .argCountMismatch:
            return MessageID(domain: "VariantIterable", id: "argCountMismatch")
        case .multiElementCaseWithAnnotation:
            return MessageID(domain: "VariantIterable", id: "multiElementCaseWithAnnotation")
        case .unexpectedArgsOnStoredProperty:
            return MessageID(domain: "VariantIterable", id: "unexpectedArgsOnStoredProperty")
        }
    }

    var severity: DiagnosticSeverity { .error }
}

// MARK: - Plugin

@main
struct VariantIterablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        VariantPeerMacro.self,
        VariantIterableMacro.self,
    ]
}

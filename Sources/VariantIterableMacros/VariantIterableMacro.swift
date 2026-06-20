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
    let isAllCases = isAllCasesMode(node)
    let entries = collectEntries(from: declaration, collectAllCases: isAllCases, in: context)
    let access = accessModifier(of: declaration)

    let body =
      entries
      .map { #"        (name: "\#($0.name)", value: \#($0.callExpr)),"# }
      .joined(separator: "\n")

    let allVariants: DeclSyntax = """
      \(raw: access)static var allVariants: [(name: String, value: Self)] {
          [
      \(raw: body)
          ]
      }
      """

    guard isAllCases else { return [allVariants] }

    let allCases: DeclSyntax = """
      \(raw: access)static var allCases: [Self] { allVariants.map(\\.value) }
      """
    return [allVariants, allCases]
  }

  // MARK: ExtensionMacro – adds VariantIterable conformance

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let conformances =
      isAllCasesMode(node)
      ? "VariantIterable, CaseIterable"
      : "VariantIterable"
    let ext: DeclSyntax = "extension \(type.trimmed): \(raw: conformances) {}"
    return [ext.cast(ExtensionDeclSyntax.self)]
  }

  // MARK: - Entry Collection

  private struct CollectedEntry {
    let name: String
    let callExpr: String
    /// Node to attach duplicate-name diagnostics to.
    let node: Syntax
    /// `true` when the name was provided explicitly via `name:` (as opposed to
    /// being derived from the member or case name).
    let explicitName: Bool
  }

  private static func collectEntries(
    from declaration: some DeclGroupSyntax,
    collectAllCases: Bool,
    in context: some MacroExpansionContext
  ) -> [(name: String, callExpr: String)] {
    var entries: [CollectedEntry] = []

    for item in declaration.memberBlock.members {
      let decl = item.decl

      // 1. enum case
      if let caseDecl = decl.as(EnumCaseDeclSyntax.self) {
        let annotations = caseDecl.attributes.variantAnnotations()

        // collectAllCases mode: auto-collect unannotated cases
        if collectAllCases && annotations.isEmpty {
          for element in caseDecl.elements {
            let params = element.parameterClause?.parameters ?? []
            if params.isEmpty {
              entries.append(
                CollectedEntry(
                  name: element.name.text,
                  callExpr: ".\(element.name.text)",
                  node: Syntax(element),
                  explicitName: false
                ))
            } else {
              context.diagnose(
                Diagnostic(
                  node: Syntax(element),
                  message: VariantDiagnostic.avCaseRequiresAnnotation(name: element.name.text)
                ))
            }
          }
          continue
        }

        guard !annotations.isEmpty else { continue }

        if caseDecl.elements.count > 1 {
          context.diagnose(
            Diagnostic(
              node: Syntax(caseDecl),
              message: VariantDiagnostic.multiElementCaseWithAnnotation
            ))
          continue
        }

        guard let element = caseDecl.elements.first else { continue }
        let caseName = element.name.text
        let params = element.parameterClause?.parameters ?? []

        for annotation in annotations {
          if annotations.count > 1 && annotation.name.isAbsent {
            context.diagnose(missingNameDiagnostic(for: annotation))
          }
          let resolved = resolveName(annotation, fallback: caseName, in: context)

          if let memberRef = annotation.memberRef {
            guard collectAllCases else {
              context.diagnose(
                Diagnostic(
                  node: Syntax(element),
                  message: VariantDiagnostic.memberRefRequiresAllCases(name: caseName)
                ))
              continue
            }
            entries.append(
              CollectedEntry(
                name: resolved.name,
                callExpr: ".\(memberRef)",
                node: Syntax(annotation.node),
                explicitName: resolved.isExplicit
              ))
            continue
          }

          guard annotation.extraArgs.count == params.count else {
            context.diagnose(
              Diagnostic(
                node: Syntax(annotation.node),
                message: VariantDiagnostic.argCountMismatch(
                  name: caseName,
                  expected: params.count,
                  actual: annotation.extraArgs.count
                )
              ))
            continue
          }

          let callExpr: String
          if params.isEmpty {
            callExpr = ".\(caseName)"
          } else {
            let labels = params.map { labelText(from: $0.firstName) }
            let avArgs = buildCallArgs(labels: labels, values: annotation.extraArgs)
            callExpr = ".\(caseName)(\(avArgs))"
          }
          entries.append(
            CollectedEntry(
              name: resolved.name,
              callExpr: callExpr,
              node: Syntax(annotation.node),
              explicitName: resolved.isExplicit
            ))
        }

        // 2. static let / var
      } else if let varDecl = decl.as(VariableDeclSyntax.self), isStatic(varDecl.modifiers) {
        let annotations = varDecl.attributes.variantAnnotations()
        guard !annotations.isEmpty else { continue }

        guard
          let memberName = varDecl.bindings.first?
            .pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        else { continue }

        for annotation in annotations {
          if !annotation.extraArgs.isEmpty {
            context.diagnose(
              Diagnostic(
                node: Syntax(annotation.node),
                message: VariantDiagnostic.unexpectedArgsOnStoredProperty(name: memberName)
              ))
            continue
          }
          if annotations.count > 1 && annotation.name.isAbsent {
            context.diagnose(missingNameDiagnostic(for: annotation))
          }
          let resolved = resolveName(annotation, fallback: memberName, in: context)
          entries.append(
            CollectedEntry(
              name: resolved.name,
              callExpr: ".\(memberName)",
              node: Syntax(annotation.node),
              explicitName: resolved.isExplicit
            ))
        }

        // 3. static func
      } else if let funcDecl = decl.as(FunctionDeclSyntax.self), isStatic(funcDecl.modifiers) {
        let annotations = funcDecl.attributes.variantAnnotations()
        guard !annotations.isEmpty else { continue }

        let funcName = funcDecl.name.text
        let params = funcDecl.signature.parameterClause.parameters
        // Parameters with a default value may be omitted from `@Variant`.
        let requiredCount = params.filter { $0.defaultValue == nil }.count

        for annotation in annotations {
          if annotations.count > 1 && annotation.name.isAbsent {
            context.diagnose(missingNameDiagnostic(for: annotation))
          }
          let resolved = resolveName(annotation, fallback: funcName, in: context)

          guard
            annotation.extraArgs.count >= requiredCount,
            annotation.extraArgs.count <= params.count
          else {
            context.diagnose(
              Diagnostic(
                node: Syntax(annotation.node),
                message: VariantDiagnostic.argCountMismatch(
                  name: funcName,
                  expected: params.count,
                  actual: annotation.extraArgs.count
                )
              ))
            continue
          }

          let callExpr: String
          if annotation.extraArgs.isEmpty {
            callExpr = ".\(funcName)()"
          } else {
            let labels = params.map { labelText(from: $0.firstName) }
            let callArgs = buildCallArgs(labels: labels, values: annotation.extraArgs)
            callExpr = ".\(funcName)(\(callArgs))"
          }
          entries.append(
            CollectedEntry(
              name: resolved.name,
              callExpr: callExpr,
              node: Syntax(annotation.node),
              explicitName: resolved.isExplicit
            ))
        }
      }
    }

    // Warn when two explicitly named entries collide. Names derived from the
    // member/case name are skipped — those collisions are already surfaced by
    // `missingNameWithMultipleVariants`.
    var seenExplicitNames = Set<String>()
    for entry in entries where entry.explicitName {
      if !seenExplicitNames.insert(entry.name).inserted {
        context.diagnose(
          Diagnostic(
            node: entry.node,
            message: VariantDiagnostic.duplicateName(name: entry.name)
          ))
      }
    }

    return entries.map { (name: $0.name, callExpr: $0.callExpr) }
  }

  // MARK: - Helpers

  private static func isAllCasesMode(_ node: AttributeSyntax) -> Bool {
    node.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "VariantIterableAllCases"
  }

  private static func isStatic(_ modifiers: DeclModifierListSyntax) -> Bool {
    modifiers.contains { $0.name.tokenKind == .keyword(.static) }
  }

  private static func labelText(from token: TokenSyntax?) -> String? {
    guard let token, token.text != "_" else { return nil }
    return token.text
  }

  private static func buildCallArgs(labels: [String?], values: [String]) -> String {
    zip(labels, values)
      .map { label, val in label.map { "\($0): \(val)" } ?? val }
      .joined(separator: ", ")
  }

  /// Resolves the display name for an annotation, emitting a diagnostic when a
  /// `name:` argument is present but not a constant string literal.
  private static func resolveName(
    _ annotation: VariantAnnotation,
    fallback: String,
    in context: some MacroExpansionContext
  ) -> (name: String, isExplicit: Bool) {
    switch annotation.name {
    case .absent:
      return (fallback, false)
    case .literal(let value):
      return (value, true)
    case .nonLiteral(let expr):
      context.diagnose(
        Diagnostic(node: Syntax(expr), message: VariantDiagnostic.nonLiteralName))
      return (fallback, false)
    }
  }

  /// Builds the `missingNameWithMultipleVariants` warning along with a fix-it
  /// that inserts a `name:` placeholder.
  private static func missingNameDiagnostic(for annotation: VariantAnnotation) -> Diagnostic {
    let placeholder = #"name: "<#name#>""#
    let newAttrText: String
    if case .argumentList(let argList)? = annotation.node.arguments, !argList.isEmpty {
      let existing = argList.map { $0.trimmedDescription }.joined(separator: ", ")
      newAttrText = "@Variant(\(existing), \(placeholder))"
    } else {
      newAttrText = "@Variant(\(placeholder))"
    }
    let parsed: AttributeSyntax = "\(raw: newAttrText)"
    let newAttr =
      parsed
      .with(\.leadingTrivia, annotation.node.leadingTrivia)
      .with(\.trailingTrivia, annotation.node.trailingTrivia)

    return Diagnostic(
      node: Syntax(annotation.node),
      message: VariantDiagnostic.missingNameWithMultipleVariants,
      fixIts: [
        FixIt(
          message: VariantFixIt.addName,
          changes: [.replace(oldNode: Syntax(annotation.node), newNode: Syntax(newAttr))]
        )
      ]
    )
  }

  private static func accessModifier(of declaration: some DeclGroupSyntax) -> String {
    for mod in declaration.modifiers {
      switch mod.name.tokenKind {
      case .keyword(.public), .keyword(.open): return "public "
      case .keyword(.package): return "package "
      // `private` and `fileprivate` types both need at least `fileprivate`
      // witnesses: the generated `allVariants` satisfies the `VariantIterable`
      // requirement from a separate extension, and a `private` member would not
      // be visible there. For a top-level type the two are equivalent anyway.
      case .keyword(.fileprivate), .keyword(.private): return "fileprivate "
      default: continue
      }
    }
    return ""
  }
}

// MARK: - VariantAnnotation

/// The resolved state of a `name:` argument.
private enum VariantName {
  /// No `name:` argument was provided.
  case absent
  /// A constant string literal (possibly empty).
  case literal(String)
  /// A `name:` argument that is not a constant string literal (e.g. an
  /// interpolated string or a reference to another value).
  case nonLiteral(ExprSyntax)

  var isAbsent: Bool {
    if case .absent = self { return true }
    return false
  }
}

private struct VariantAnnotation {
  let node: AttributeSyntax
  let name: VariantName
  /// Non-nil when `@Variant(at:)` is used.
  let memberRef: String?
  /// Positional argument expressions (source text) for `@Variant(arg1, arg2, ...)`.
  let extraArgs: [String]
}

extension AttributeListSyntax {
  fileprivate func variantAnnotations() -> [VariantAnnotation] {
    compactMap { element -> VariantAnnotation? in
      guard case .attribute(let attr) = element,
        attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "Variant"
      else { return nil }

      guard let args = attr.arguments,
        case .argumentList(let argList) = args
      else {
        // @Variant with no parentheses
        return VariantAnnotation(node: attr, name: .absent, memberRef: nil, extraArgs: [])
      }

      var name: VariantName = .absent
      var memberRef: String? = nil
      var extraArgs: [String] = []

      for arg in argList {
        switch arg.label?.text {
        case "name": name = parseVariantName(arg.expression)
        case "at":
          if let memberAccess = arg.expression.as(MemberAccessExprSyntax.self) {
            memberRef = memberAccess.declName.baseName.text
          }
        case nil: extraArgs.append(arg.expression.trimmedDescription)
        default: break
        }
      }

      if memberRef != nil {
        return VariantAnnotation(node: attr, name: name, memberRef: memberRef, extraArgs: [])
      }
      return VariantAnnotation(node: attr, name: name, memberRef: nil, extraArgs: extraArgs)
    }
  }
}

// MARK: - Name Parsing

/// Parses a `name:` argument expression into a `VariantName`.
///
/// Returns `.literal` only for constant string literals (empty strings
/// included). Interpolated strings, other expressions, and explicit `nil` that
/// cannot be embedded as a compile-time name are reported back to the caller.
private func parseVariantName(_ expr: ExprSyntax) -> VariantName {
  if expr.is(NilLiteralExprSyntax.self) { return .absent }
  guard let strLit = expr.as(StringLiteralExprSyntax.self) else { return .nonLiteral(expr) }
  var result = ""
  for segment in strLit.segments {
    guard let text = segment.as(StringSegmentSyntax.self)?.content.text else {
      return .nonLiteral(expr)
    }
    result += text
  }
  return .literal(result)
}

// MARK: - Diagnostics

private enum VariantDiagnostic: DiagnosticMessage {
  case argCountMismatch(name: String, expected: Int, actual: Int)
  case avCaseRequiresAnnotation(name: String)
  case duplicateName(name: String)
  case memberRefRequiresAllCases(name: String)
  case multiElementCaseWithAnnotation
  case missingNameWithMultipleVariants
  case nonLiteralName
  case unexpectedArgsOnStoredProperty(name: String)

  var message: String {
    switch self {
    case .argCountMismatch(let name, let expected, let actual):
      return "@Variant: '\(name)' expects \(expected) argument(s) but \(actual) were provided."
    case .avCaseRequiresAnnotation(let name):
      return
        "@VariantIterableAllCases: '\(name)' has associated values and requires an explicit @Variant annotation."
    case .duplicateName(let name):
      return
        "@Variant: duplicate name '\(name)'. allVariants will contain more than one entry with this name."
    case .memberRefRequiresAllCases(let name):
      return
        "@Variant(at:) is only supported with @VariantIterableAllCases. To include '\(name)' with @VariantIterable, annotate the static let with @Variant directly."
    case .multiElementCaseWithAnnotation:
      return
        "@Variant cannot be applied to a multi-element case declaration (e.g. `case a, b`). Declare each case on its own line."
    case .missingNameWithMultipleVariants:
      return
        "@Variant: 'name:' is required when multiple @Variant attributes are applied to the same declaration."
    case .nonLiteralName:
      return
        "@Variant: 'name:' must be a constant string literal. Interpolated or computed names cannot be used."
    case .unexpectedArgsOnStoredProperty(let name):
      return "@Variant: '\(name)' expects no arguments."
    }
  }

  private static let domain = "VariantIterable"

  var diagnosticID: MessageID {
    switch self {
    case .argCountMismatch:
      return MessageID(domain: Self.domain, id: "argCountMismatch")
    case .avCaseRequiresAnnotation:
      return MessageID(domain: Self.domain, id: "avCaseRequiresAnnotation")
    case .duplicateName:
      return MessageID(domain: Self.domain, id: "duplicateName")
    case .memberRefRequiresAllCases:
      return MessageID(domain: Self.domain, id: "memberRefRequiresAllCases")
    case .multiElementCaseWithAnnotation:
      return MessageID(domain: Self.domain, id: "multiElementCaseWithAnnotation")
    case .missingNameWithMultipleVariants:
      return MessageID(domain: Self.domain, id: "missingNameWithMultipleVariants")
    case .nonLiteralName:
      return MessageID(domain: Self.domain, id: "nonLiteralName")
    case .unexpectedArgsOnStoredProperty:
      return MessageID(domain: Self.domain, id: "unexpectedArgsOnStoredProperty")
    }
  }

  var severity: DiagnosticSeverity {
    switch self {
    case .missingNameWithMultipleVariants, .duplicateName: return .warning
    default: return .error
    }
  }
}

private enum VariantFixIt: FixItMessage {
  case addName

  var message: String {
    switch self {
    case .addName: return "Add 'name:'"
    }
  }

  var fixItID: MessageID {
    switch self {
    case .addName: return MessageID(domain: "VariantIterable", id: "addName")
    }
  }
}

// MARK: - Plugin

@main
struct VariantIterablePlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    VariantPeerMacro.self,
    VariantIterableMacro.self,
  ]
}

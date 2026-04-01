// MARK: - Protocol

/// A type that provides a named list of its representative variant instances.
///
/// Adopt this protocol by applying `@VariantIterable` to your struct or enum.
/// Use `@Variant` to register each representative instance.
public protocol VariantIterable: Sendable {
    static var allVariants: [(name: String, value: Self)] { get }
}

// MARK: - @VariantIterable

/// Generates `VariantIterable` conformance and synthesizes `allVariants` from
/// members and enum cases annotated with `@Variant`.
@attached(member, names: named(allVariants))
@attached(extension, conformances: VariantIterable)
public macro VariantIterable() = #externalMacro(
    module: "VariantIterableMacros",
    type: "VariantIterableMacro"
)

// MARK: - @Variant

/// Registers a static member or enum case as an entry in `allVariants`.
///
/// **Supported targets:**
/// - `static let` / `static var`: included directly. Positional arguments are not allowed.
/// - `static func` (no parameters): called with no arguments.
/// - `static func` (with parameters): pass positional arguments before `name:`.
/// - `enum case` (no associated values): included as-is. No arguments needed.
/// - `enum case` (with associated values): pass positional arguments matching the AV list.
/// - `enum case` (with closure AV or other non-literal AV): add `@Variant` to a
///   `static let` that constructs the case, and annotate that static member instead.
///
/// `name:` is optional; when omitted, the member or case name is used as-is.
///
/// Apply multiple `@Variant` attributes to the same declaration to register
/// multiple entries (useful for parameterised functions and AV cases).
@attached(peer)
public macro Variant<each A>(_ args: repeat each A, name: String? = nil) = #externalMacro(
    module: "VariantIterableMacros",
    type: "VariantPeerMacro"
)

/// Registers an enum case by referencing an existing static member that provides
/// the representative instance. Use this when the associated value cannot be
/// expressed as a macro argument (e.g. closures).
///
/// ```swift
/// @Variant(member: "logoutAction", name: "ログアウト")
/// case withAction(String, () -> Void)
///
/// static let logoutAction = Self.withAction("ログアウト") { /* ... */ }
/// ```
@attached(peer)
public macro Variant(member: String, name: String? = nil) = #externalMacro(
    module: "VariantIterableMacros",
    type: "VariantPeerMacro"
)

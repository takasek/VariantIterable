import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(VariantIterableMacros)
import VariantIterableMacros

private let testMacros: [String: Macro.Type] = [
    "VariantIterable": VariantIterableMacro.self,
    "VariantIterableAllCases": VariantIterableMacro.self,
    "Variant": VariantPeerMacro.self,
]
#endif

final class VariantIterableMacroTests: XCTestCase {

    // MARK: - struct: static let

    func testStaticLetIsCollected() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            public struct Config {
                @Variant(name: "Logout")
                public static let logout: Self = .init()
            }
            """,
            expandedSource: """
            public struct Config {
                public static let logout: Self = .init()

                public static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Logout", value: .logout),
                    ]
                }
            }

            extension Config: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testStaticLetWithoutAnnotationIsSkipped() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            struct Config {
                @Variant(name: "A")
                static let a: Self = .init()
                static let b: Self = .init()
            }
            """,
            expandedSource: """
            struct Config {
                static let a: Self = .init()
                static let b: Self = .init()

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "A", value: .a),
                    ]
                }
            }

            extension Config: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testStaticLetNameOmitted() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            struct Config {
                @Variant
                static let logout: Self = .init()
            }
            """,
            expandedSource: """
            struct Config {
                static let logout: Self = .init()

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "logout", value: .logout),
                    ]
                }
            }

            extension Config: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - struct: static func

    func testNoArgStaticFuncIsCollected() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            struct Config {
                @Variant(name: "Default")
                static func makeDefault() -> Self { .init() }
            }
            """,
            expandedSource: """
            struct Config {
                static func makeDefault() -> Self { .init() }

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Default", value: .makeDefault()),
                    ]
                }
            }

            extension Config: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testSingleArgStaticFuncIsCollected() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            struct Config {
                @Variant(30, name: "Custom")
                static func custom(timeout: Double) -> Self { .init() }
            }
            """,
            expandedSource: """
            struct Config {
                static func custom(timeout: Double) -> Self { .init() }

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Custom", value: .custom(timeout: 30)),
                    ]
                }
            }

            extension Config: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMultipleVariantOnSameFuncGeneratesMultipleEntries() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            struct Config {
                @Variant(5, name: "Aggressive")
                @Variant(120, name: "Lenient")
                static func custom(timeout: Double) -> Self { .init() }
            }
            """,
            expandedSource: """
            struct Config {
                static func custom(timeout: Double) -> Self { .init() }

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Aggressive", value: .custom(timeout: 5)),
                        (name: "Lenient", value: .custom(timeout: 120)),
                    ]
                }
            }

            extension Config: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testUnlabeledParamStaticFunc() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            struct Config {
                @Variant(42, name: "ID=42")
                static func byID(_ id: Int) -> Self { .init() }
            }
            """,
            expandedSource: """
            struct Config {
                static func byID(_ id: Int) -> Self { .init() }

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "ID=42", value: .byID(42)),
                    ]
                }
            }

            extension Config: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - struct: diagnostics

    func testExtraArgsOnStaticLetProducesDiagnostic() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            struct Config {
                @Variant(42, name: "bad")
                static let logout: Self = .init()
            }
            """,
            expandedSource: """
            struct Config {
                static let logout: Self = .init()

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension Config: VariantIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Variant: 'logout' is a stored property; positional arguments are not allowed.",
                    line: 3,
                    column: 5,
                    severity: .error
                )
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testArgCountMismatchOnFuncProducesDiagnostic() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            struct Config {
                @Variant(1, 2, name: "too many")
                static func byID(_ id: Int) -> Self { .init() }
            }
            """,
            expandedSource: """
            struct Config {
                static func byID(_ id: Int) -> Self { .init() }

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension Config: VariantIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Variant: 'byID' expects 1 argument(s) but 2 were provided.",
                    line: 3,
                    column: 5,
                    severity: .error
                )
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - enum: AV-less case

    func testAVLessCaseWithAnnotation() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            enum Alert {
                @Variant(name: "Logout confirmation")
                case logout
                case notification
            }
            """,
            expandedSource: """
            enum Alert {
                case logout
                case notification

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Logout confirmation", value: .logout),
                    ]
                }
            }

            extension Alert: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testUnannotatedCaseIsSkipped() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            enum Alert {
                @Variant(name: "A")
                case shown
                case hidden
            }
            """,
            expandedSource: """
            enum Alert {
                case shown
                case hidden

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "A", value: .shown),
                    ]
                }
            }

            extension Alert: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - enum: AV case

    func testAVCaseWithSingleArg() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            enum Alert {
                @Variant("Short message", name: "Short")
                @Variant("A much longer error message for testing layout.", name: "Long")
                case message(String)
            }
            """,
            expandedSource: """
            enum Alert {
                case message(String)

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Short", value: .message("Short message")),
                        (name: "Long", value: .message("A much longer error message for testing layout.")),
                    ]
                }
            }

            extension Alert: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testAVCaseWithLabeledParam() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            enum Alert {
                @Variant(503, name: "Server Error")
                case httpError(code: Int)
            }
            """,
            expandedSource: """
            enum Alert {
                case httpError(code: Int)

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Server Error", value: .httpError(code: 503)),
                    ]
                }
            }

            extension Alert: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - enum: member: overload

    func testMemberRefOnVariantIterableProducesDiagnostic() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            enum Alert {
                @Variant(at: Self.logoutAction, name: "Logout")
                case withAction(String, () -> Void)

                static let logoutAction = Alert.withAction("Sign out?") {}
            }
            """,
            expandedSource: """
            enum Alert {
                case withAction(String, () -> Void)

                static let logoutAction = Alert.withAction("Sign out?") {}

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension Alert: VariantIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Variant(at:) is only supported with @VariantIterableAllCases. To include 'withAction' with @VariantIterable, annotate the static let with @Variant directly.",
                    line: 4,
                    column: 10,
                    severity: .error
                )
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - enum: @VariantIterableAllCases

    func testAllCasesAutoCollectsAVLessCases() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterableAllCases
            enum Status {
                case active
                case inactive
                case pending
            }
            """,
            expandedSource: """
            enum Status {
                case active
                case inactive
                case pending

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "active", value: .active),
                        (name: "inactive", value: .inactive),
                        (name: "pending", value: .pending),
                    ]
                }

                static var allCases: [Self] {
                    allVariants.map(\\.value)
                }
            }

            extension Status: VariantIterable, CaseIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testAllCasesExplicitAnnotationOverridesName() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterableAllCases
            enum Status {
                case active
                @Variant(name: "Not active")
                case inactive
            }
            """,
            expandedSource: """
            enum Status {
                case active
                case inactive

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "active", value: .active),
                        (name: "Not active", value: .inactive),
                    ]
                }

                static var allCases: [Self] {
                    allVariants.map(\\.value)
                }
            }

            extension Status: VariantIterable, CaseIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testAllCasesMultiElementCaseAutoCollected() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterableAllCases
            enum Status {
                case active, inactive
            }
            """,
            expandedSource: """
            enum Status {
                case active, inactive

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "active", value: .active),
                        (name: "inactive", value: .inactive),
                    ]
                }

                static var allCases: [Self] {
                    allVariants.map(\\.value)
                }
            }

            extension Status: VariantIterable, CaseIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testAllCasesMemberRefCombined() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterableAllCases
            enum Config {
                case simple
                @Variant(at: Self.largePayload, name: "Large payload")
                case withData(Data)
                static let largePayload = Config.withData(Data())
            }
            """,
            expandedSource: """
            enum Config {
                case simple
                case withData(Data)
                static let largePayload = Config.withData(Data())

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "simple", value: .simple),
                        (name: "Large payload", value: .largePayload),
                    ]
                }

                static var allCases: [Self] {
                    allVariants.map(\\.value)
                }
            }

            extension Config: VariantIterable, CaseIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testAllCasesAVCaseWithoutAnnotationProducesDiagnostic() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterableAllCases
            enum Alert {
                case success
                case error(String)
            }
            """,
            expandedSource: """
            enum Alert {
                case success
                case error(String)

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "success", value: .success),
                    ]
                }

                static var allCases: [Self] {
                    allVariants.map(\\.value)
                }
            }

            extension Alert: VariantIterable, CaseIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@VariantIterableAllCases: 'error' has associated values and requires an explicit @Variant annotation.",
                    line: 4,
                    column: 10,
                    severity: .error
                )
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - enum: diagnostics

    func testMultiElementCaseWithAnnotationProducesDiagnostic() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            enum Alert {
                @Variant(name: "bad")
                case a, b
            }
            """,
            expandedSource: """
            enum Alert {
                case a, b

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension Alert: VariantIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Variant cannot be applied to a multi-element case declaration (e.g. `case a, b`). Declare each case on its own line.",
                    line: 3,
                    column: 5,
                    severity: .error
                )
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testAVArgCountMismatchProducesDiagnostic() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            enum Alert {
                @Variant("hello", "world", name: "too many")
                case message(String)
            }
            """,
            expandedSource: """
            enum Alert {
                case message(String)

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension Alert: VariantIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Variant: 'message' expects 1 argument(s) but 2 were provided.",
                    line: 4,
                    column: 10,
                    severity: .error
                )
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}

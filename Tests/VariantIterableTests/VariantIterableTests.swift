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
            public struct X {
                @Variant(name: "Foo")
                public static let foo: Self = .init()
            }
            """,
            expandedSource: """
            public struct X {
                public static let foo: Self = .init()

                public static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Foo", value: .foo),
                    ]
                }
            }

            extension X: VariantIterable {
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
            struct X {
                @Variant(name: "Foo")
                static let foo: Self = .init()
                static let bar: Self = .init()
            }
            """,
            expandedSource: """
            struct X {
                static let foo: Self = .init()
                static let bar: Self = .init()

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Foo", value: .foo),
                    ]
                }
            }

            extension X: VariantIterable {
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
            struct X {
                @Variant
                static let foo: Self = .init()
            }
            """,
            expandedSource: """
            struct X {
                static let foo: Self = .init()

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "foo", value: .foo),
                    ]
                }
            }

            extension X: VariantIterable {
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
            struct X {
                @Variant(name: "Foo")
                static func make() -> Self { .init() }
            }
            """,
            expandedSource: """
            struct X {
                static func make() -> Self { .init() }

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Foo", value: .make()),
                    ]
                }
            }

            extension X: VariantIterable {
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
            struct X {
                @Variant(1, name: "Foo")
                static func make(value: Int) -> Self { .init() }
            }
            """,
            expandedSource: """
            struct X {
                static func make(value: Int) -> Self { .init() }

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Foo", value: .make(value: 1)),
                    ]
                }
            }

            extension X: VariantIterable {
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
            struct X {
                @Variant(1, name: "Foo")
                @Variant(2, name: "Bar")
                static func make(value: Int) -> Self { .init() }
            }
            """,
            expandedSource: """
            struct X {
                static func make(value: Int) -> Self { .init() }

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Foo", value: .make(value: 1)),
                        (name: "Bar", value: .make(value: 2)),
                    ]
                }
            }

            extension X: VariantIterable {
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
            struct X {
                @Variant(1, name: "Foo")
                static func make(_ n: Int) -> Self { .init() }
            }
            """,
            expandedSource: """
            struct X {
                static func make(_ n: Int) -> Self { .init() }

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Foo", value: .make(1)),
                    ]
                }
            }

            extension X: VariantIterable {
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
            struct X {
                @Variant(1, name: "bad")
                static let foo: Self = .init()
            }
            """,
            expandedSource: """
            struct X {
                static let foo: Self = .init()

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension X: VariantIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Variant: 'foo' expects no arguments.",
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
            struct X {
                @Variant(1, 2, name: "bad")
                static func make(_ n: Int) -> Self { .init() }
            }
            """,
            expandedSource: """
            struct X {
                static func make(_ n: Int) -> Self { .init() }

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension X: VariantIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Variant: 'make' expects 1 argument(s) but 2 were provided.",
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
            enum X {
                @Variant(name: "Foo")
                case foo
                case bar
            }
            """,
            expandedSource: """
            enum X {
                case foo
                case bar

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Foo", value: .foo),
                    ]
                }
            }

            extension X: VariantIterable {
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
            enum X {
                case foo
                case bar
            }
            """,
            expandedSource: """
            enum X {
                case foo
                case bar

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension X: VariantIterable {
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
            enum X {
                @Variant("foo", name: "Foo")
                @Variant("bar", name: "Bar")
                case baz(String)
            }
            """,
            expandedSource: """
            enum X {
                case baz(String)

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Foo", value: .baz("foo")),
                        (name: "Bar", value: .baz("bar")),
                    ]
                }
            }

            extension X: VariantIterable {
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
            enum X {
                @Variant(1, name: "Foo")
                case foo(x: Int)
            }
            """,
            expandedSource: """
            enum X {
                case foo(x: Int)

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Foo", value: .foo(x: 1)),
                    ]
                }
            }

            extension X: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testAVCaseWithMultipleArgs() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            enum X {
                @Variant("foo", 1, name: "Foo")
                case bar(x: String, y: Int)
            }
            """,
            expandedSource: """
            enum X {
                case bar(x: String, y: Int)

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "Foo", value: .bar(x: "foo", y: 1)),
                    ]
                }
            }

            extension X: VariantIterable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - enum: @Variant(at:) overload

    func testMemberRefOnVariantIterableProducesDiagnostic() throws {
        #if canImport(VariantIterableMacros)
        assertMacroExpansion(
            """
            @VariantIterable
            enum X {
                @Variant(at: Self.bar, name: "Bar")
                case foo(() -> Void)

                static let bar = X.foo({})
            }
            """,
            expandedSource: """
            enum X {
                case foo(() -> Void)

                static let bar = X.foo({})

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension X: VariantIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Variant(at:) is only supported with @VariantIterableAllCases. To include 'foo' with @VariantIterable, annotate the static let with @Variant directly.",
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
            enum X {
                case foo
                case bar
                case baz
            }
            """,
            expandedSource: """
            enum X {
                case foo
                case bar
                case baz

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "foo", value: .foo),
                        (name: "bar", value: .bar),
                        (name: "baz", value: .baz),
                    ]
                }

                static var allCases: [Self] {
                    allVariants.map(\\.value)
                }
            }

            extension X: VariantIterable, CaseIterable {
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
            enum X {
                case foo
                @Variant(name: "Bar!")
                case bar
            }
            """,
            expandedSource: """
            enum X {
                case foo
                case bar

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "foo", value: .foo),
                        (name: "Bar!", value: .bar),
                    ]
                }

                static var allCases: [Self] {
                    allVariants.map(\\.value)
                }
            }

            extension X: VariantIterable, CaseIterable {
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
            enum X {
                case foo, bar
            }
            """,
            expandedSource: """
            enum X {
                case foo, bar

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "foo", value: .foo),
                        (name: "bar", value: .bar),
                    ]
                }

                static var allCases: [Self] {
                    allVariants.map(\\.value)
                }
            }

            extension X: VariantIterable, CaseIterable {
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
            enum X {
                case foo
                @Variant(at: Self.baz, name: "Baz")
                case bar(Data)
                static let baz = X.bar(Data())
            }
            """,
            expandedSource: """
            enum X {
                case foo
                case bar(Data)
                static let baz = X.bar(Data())

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "foo", value: .foo),
                        (name: "Baz", value: .baz),
                    ]
                }

                static var allCases: [Self] {
                    allVariants.map(\\.value)
                }
            }

            extension X: VariantIterable, CaseIterable {
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
            enum X {
                case foo
                case bar(String)
            }
            """,
            expandedSource: """
            enum X {
                case foo
                case bar(String)

                static var allVariants: [(name: String, value: Self)] {
                    [
                        (name: "foo", value: .foo),
                    ]
                }

                static var allCases: [Self] {
                    allVariants.map(\\.value)
                }
            }

            extension X: VariantIterable, CaseIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@VariantIterableAllCases: 'bar' has associated values and requires an explicit @Variant annotation.",
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
            enum X {
                @Variant(name: "bad")
                case foo, bar
            }
            """,
            expandedSource: """
            enum X {
                case foo, bar

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension X: VariantIterable {
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
            enum X {
                @Variant("foo", "bar", name: "bad")
                case baz(String)
            }
            """,
            expandedSource: """
            enum X {
                case baz(String)

                static var allVariants: [(name: String, value: Self)] {
                    [

                    ]
                }
            }

            extension X: VariantIterable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Variant: 'baz' expects 1 argument(s) but 2 were provided.",
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

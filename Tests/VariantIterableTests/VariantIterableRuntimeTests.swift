import VariantIterable
import XCTest

// These tests exercise the *generated* code at runtime — they compile the macro
// expansion and assert on the resulting `allVariants` / `allCases`. This catches
// regressions that pure `assertMacroExpansion` string comparisons cannot, e.g.
// expansions that produce text which does not actually compile or evaluate.

@VariantIterable
private struct RuntimeConfig: Equatable {
  let id: Int

  @Variant(name: "First")
  static let first = RuntimeConfig(id: 1)

  @Variant
  static let second = RuntimeConfig(id: 2)

  @Variant(10, name: "Ten")
  @Variant(name: "Default")
  static func make(id: Int = 0) -> RuntimeConfig { .init(id: id) }
}

@VariantIterableAllCases
private enum RuntimeStatus: Equatable {
  case active
  case inactive

  @Variant("boom", name: "Failure")
  case failure(String)
}

final class VariantIterableRuntimeTests: XCTestCase {

  func testStructAllVariantsNamesAndValues() {
    XCTAssertEqual(
      RuntimeConfig.allVariants.map(\.name),
      ["First", "second", "Ten", "Default"]
    )
    XCTAssertEqual(
      RuntimeConfig.allVariants.map(\.value),
      [
        RuntimeConfig(id: 1),
        RuntimeConfig(id: 2),
        RuntimeConfig(id: 10),
        RuntimeConfig(id: 0),
      ]
    )
  }

  func testEnumAllVariantsAndAllCasesStayInSync() {
    XCTAssertEqual(
      RuntimeStatus.allVariants.map(\.name),
      ["active", "inactive", "Failure"]
    )
    XCTAssertEqual(
      RuntimeStatus.allCases,
      [.active, .inactive, .failure("boom")]
    )
    XCTAssertEqual(
      RuntimeStatus.allCases,
      RuntimeStatus.allVariants.map(\.value)
    )
  }
}

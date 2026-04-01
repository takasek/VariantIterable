import Foundation
import VariantIterable

// MARK: - struct

/// A snapshot of network settings used to drive a particular build environment.
@VariantIterable
public struct NetworkConfig: CustomStringConvertible, Sendable {
    public let baseURL: String
    public let timeout: TimeInterval

    public var description: String { "NetworkConfig(baseURL: \"\(baseURL)\", timeout: \(timeout)s)" }

    @Variant
    public static let development = NetworkConfig(baseURL: "http://localhost:8080", timeout: 60)

    @Variant
    public static let staging = NetworkConfig(baseURL: "https://staging.example.com", timeout: 30)

    @Variant
    public static let production = NetworkConfig(baseURL: "https://api.example.com", timeout: 10)

    @Variant(5, name: "Aggressive")
    @Variant(120, name: "Lenient")
    public static func custom(timeout: TimeInterval) -> NetworkConfig {
        NetworkConfig(baseURL: "https://api.example.com", timeout: timeout)
    }
}

print("=== NetworkConfig.allVariants ===")
for (name, value) in NetworkConfig.allVariants {
    print("  [\(name)] \(value)")
}

// MARK: - enum

/// In-app banners shown to the user.
@VariantIterable
public enum Banner: Sendable {
    @Variant(name: "Success")
    case success

    @Variant(name: "Warning")
    case warning

    @Variant("Oops, something went wrong.", name: "Short error")
    @Variant("A network error occurred. Please check your connection and try again.", name: "Long error")
    case error(String)

    @Variant(503, name: "Server Error")
    case httpError(code: Int)

    @Variant(Date.distantFuture, name: "Far future")
    case scheduledMaintenance(at: Date)
}

print("\n=== Banner.allVariants ===")
for (name, _) in Banner.allVariants {
    print("  [\(name)]")
}

// MARK: - @VariantIterableAllCases + @Variant(at:)

/// Payloads attached to a request.
@VariantIterableAllCases
public enum Payload: Sendable {
    case empty

    @Variant(at: Self.largeBody, name: "Large body")
    case body(Data)

    static let largeBody = Self.body(Data(repeating: 0xFF, count: 1024))
}

print("\n=== Payload.allVariants ===")
for (name, _) in Payload.allVariants {
    print("  [\(name)]")
}
print("allCases count: \(Payload.allCases.count)")

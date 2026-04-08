import CryptoKit
import Foundation

public struct RuleSigner {
    public init() {}

    public func sha256Hex(of value: String) -> String {
        sha256Hex(data: Data(value.utf8))
    }

    public func sha256Hex(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

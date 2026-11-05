import Foundation
import Security

/// Secrets (the GitHub token) live only in the iPhone's Keychain, never in code, files or GitHub.
enum KeychainStore {
    static let service = "com.fady.glasslookstore"
    static let githubToken = "github.token"

    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        delete(key)
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: key, kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: key, kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }

    /// Only the last 4 characters are ever shown outside the field.
    static func masked(_ value: String?) -> String {
        guard let v = value, v.count > 4 else { return "Not added" }
        return "•••• " + String(v.suffix(4))
    }
}

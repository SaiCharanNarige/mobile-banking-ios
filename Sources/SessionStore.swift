import Foundation
import Security

struct StoredSession: Codable {
    let session: BankSession
    let mode: Int
}

/// Passwords are never persisted; only the session token and expiry go in Keychain.
struct SessionStore {
    private let service = "com.portfolio.MobileBanking.session"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "active-session"]
    }
    func save(_ value: StoredSession) throws {
        let data = try JSONEncoder().encode(value)
        let changes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let result = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if result == errSecItemNotFound {
            var insertion = query
            changes.forEach { insertion[$0.key] = $0.value }
            let status = SecItemAdd(insertion as CFDictionary, nil)
            guard status == errSecSuccess else { throw BankError.keychain(status) }
        } else if result != errSecSuccess { throw BankError.keychain(result) }
    }
    func load() throws -> StoredSession? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw BankError.keychain(status) }
        guard let data = result as? Data else { throw BankError.invalidResponse }
        return try JSONDecoder().decode(StoredSession.self, from: data)
    }
    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw BankError.keychain(status) }
    }
}

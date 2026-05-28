import Foundation
import Security

// Tiny wrapper around the macOS keychain for storing a single string per key
// in the generic-password class. We only need it for the server API token.
enum KeychainStore {
    static let service = "com.adamcuppy.QuadrantTimer"

    static func read(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query = baseQuery(account)
        let attributes = [kSecValueData as String: data] as CFDictionary

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func delete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

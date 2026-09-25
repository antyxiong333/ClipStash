import Foundation
import Security

enum AISettings {
    private static let service = "com.clipstash.app.ai"
    private static let openAIAccount = "openai-api-key"
    private static let huggingFaceAccount = "huggingface-read-token"

    static func openAIAPIKey() -> String? {
        value(account: openAIAccount)
    }

    static func saveOpenAIAPIKey(_ key: String) throws {
        try save(key, account: openAIAccount)
    }

    static func huggingFaceAccessToken() -> String? {
        value(account: huggingFaceAccount)
    }

    static func saveHuggingFaceAccessToken(_ token: String) throws {
        try save(token, account: huggingFaceAccount)
    }

    private static func value(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else { return nil }
        return value
    }

    private static func save(_ key: String, account: String) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if trimmedKey.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError(status: status)
            }
            return
        }

        let attributes = [kSecValueData as String: Data(trimmedKey.utf8)]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = Data(trimmedKey.utf8)
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainError(status: updateStatus)
        }
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String? ?? "Could not update the API key."
    }
}

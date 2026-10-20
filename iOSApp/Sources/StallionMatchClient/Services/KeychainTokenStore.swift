import Foundation
import Security

public struct StoredTokenPair: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String

    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

public protocol TokenStore: Sendable {
    func loadTokens() async -> StoredTokenPair?
    func saveTokens(_ pair: StoredTokenPair) async throws
    func clearTokens() async throws
}

/// Keychain-only token storage. Never touches UserDefaults.
public actor KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String

    public init(
        service: String = "com.stallionmatch.app.tokens",
        account: String = "auth_token_pair"
    ) {
        self.service = service
        self.account = account
    }

    public func loadTokens() async -> StoredTokenPair? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(StoredTokenPair.self, from: data)
    }

    public func saveTokens(_ pair: StoredTokenPair) async throws {
        let data = try JSONEncoder().encode(pair)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unhandledStatus(updateStatus)
        }
    }

    public func clearTokens() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}

public enum KeychainError: Error, LocalizedError, Sendable, Equatable {
    case unhandledStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

/// Thread-safe in-memory token store for previews and unit tests.
public actor InMemoryTokenStore: TokenStore {
    private var currentPair: StoredTokenPair?

    public init(initial: StoredTokenPair? = nil) {
        self.currentPair = initial
    }

    public func loadTokens() async -> StoredTokenPair? {
        currentPair
    }

    public func saveTokens(_ pair: StoredTokenPair) async throws {
        currentPair = pair
    }

    public func clearTokens() async throws {
        currentPair = nil
    }
}

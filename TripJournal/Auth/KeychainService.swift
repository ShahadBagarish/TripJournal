//
//  KeychainService.swift
//  TripJournal
//
//  Created by Shahad Bagarish on 12/01/2026.
//
import Security
import Foundation

enum KeychainService {
    static let tokenKey = "auth_token"

    static func save(_ token: AuthToken) {
        guard let data = try? JSONEncoder().encode(token) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary) // remove old
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> AuthToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard
            status == errSecSuccess,
            let data = item as? Data,
            let token = try? JSONDecoder().decode(AuthToken.self, from: data)
        else {
            return nil
        }

        return token
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}

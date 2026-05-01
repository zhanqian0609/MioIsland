//
//  KeyManager.swift
//  ClaudeIsland
//
//  Stores the sync identity keypair and per-server auth tokens in Keychain.
//

import CryptoKit
import Foundation
import Security

struct AuthRequest: Codable {
    let publicKey: String
    let challenge: String
    let signature: String
}

struct AuthResponse: Codable {
    let token: String?
    let deviceId: String?
}

enum KeyManagerError: LocalizedError {
    case invalidKeyData
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidKeyData:
            return "Stored identity key is invalid."
        case .keychainFailure(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

final class KeyManager {
    private let serviceName: String
    private let identityAccount = "sync.identity.ed25519"
    private let tokenPrefix = "sync.token."

    nonisolated init(serviceName: String) {
        self.serviceName = serviceName
    }

    @discardableResult
    func getOrCreateIdentityKey() throws -> Curve25519.Signing.PrivateKey {
        if let existing = try loadIdentityKey() {
            return existing
        }

        let created = Curve25519.Signing.PrivateKey()
        try save(data: created.rawRepresentation, account: identityAccount)
        return created
    }

    func sign(_ data: Data) throws -> Data {
        let key = try getOrCreateIdentityKey()
        return try key.signature(for: data)
    }

    func publicKeyBase64() throws -> String {
        let key = try getOrCreateIdentityKey()
        return key.publicKey.rawRepresentation.base64EncodedString()
    }

    func loadToken(forServer serverUrl: String) -> String? {
        guard let data = try? load(account: tokenAccount(for: serverUrl)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func storeToken(_ token: String, forServer serverUrl: String) throws {
        try save(data: Data(token.utf8), account: tokenAccount(for: serverUrl))
    }

    private func loadIdentityKey() throws -> Curve25519.Signing.PrivateKey? {
        guard let data = try load(account: identityAccount) else { return nil }
        do {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        } catch {
            throw KeyManagerError.invalidKeyData
        }
    }

    private func tokenAccount(for serverUrl: String) -> String {
        tokenPrefix + serverUrl
    }

    private func load(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeyManagerError.keychainFailure(status)
        }
    }

    private func save(data: Data, account: String) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]

        let updateAttrs = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw KeyManagerError.keychainFailure(updateStatus)
        }

        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeyManagerError.keychainFailure(addStatus)
        }
    }
}

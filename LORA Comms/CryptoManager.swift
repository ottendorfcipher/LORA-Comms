import Foundation
import CryptoKit
import Security

// MARK: - CryptoManager Error

enum CryptoManagerError: Error {
    case keyGenerationFailed
    case keyNotFound
    case encryptionFailed
    case decryptionFailed
    case dataToStringConversionFailed
    case stringToDataConversionFailed
}

// MARK: - CryptoManager

class CryptoManager {
    static let shared = CryptoManager()
    private let keychainService = "com.techKinect.LORA-Comms.encryption-key"
    private var encryptionKey: SymmetricKey?

    private init() {
        // Try to load the key from the Keychain upon initialization
        self.encryptionKey = loadKey()
        if self.encryptionKey == nil {
            // If no key is found, generate a new one and save it
            do {
                self.encryptionKey = try generateAndSaveKey()
            } catch {
                print("Error generating and saving key: \(error)")
            }
        }
    }

    // MARK: - Key Management

    private func generateAndSaveKey() throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256) // AES-256
        let keyData = key.withUnsafeBytes { Data(Array($0)) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete any existing key before saving the new one
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CryptoManagerError.keyGenerationFailed
        }

        return key
    }

    private func loadKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let keyData = item as? Data else {
            return nil
        }

        return SymmetricKey(data: keyData)
    }

    func regenerateKey() throws {
        self.encryptionKey = try generateAndSaveKey()
    }

    func exportKey() -> Data? {
        return encryptionKey?.withUnsafeBytes { Data(Array($0)) }
    }

    func importKey(from data: Data) {
        self.encryptionKey = SymmetricKey(data: data)
        // Save the imported key to the Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    // MARK: - Encryption & Decryption

    func encrypt(string: String) throws -> String {
        guard let key = encryptionKey else { throw CryptoManagerError.keyNotFound }
        guard let data = string.data(using: .utf8) else { throw CryptoManagerError.stringToDataConversionFailed }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined!.base64EncodedString()
        } catch {
            throw CryptoManagerError.encryptionFailed
        }
    }

    func decrypt(base64String: String) throws -> String {
        guard let key = encryptionKey else { throw CryptoManagerError.keyNotFound }
        guard let data = Data(base64Encoded: base64String) else { throw CryptoManagerError.stringToDataConversionFailed }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
                throw CryptoManagerError.dataToStringConversionFailed
            }
            return decryptedString
        } catch {
            throw CryptoManagerError.decryptionFailed
        }
    }
}


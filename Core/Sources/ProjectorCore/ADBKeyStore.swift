import Foundation
import Security
import SwiftADB

public enum ADBKeyStore {
    public static func loadOrCreate() throws -> KeyPair {
        let tag = Data("app.aleko.ProjectorRemote.adb.rsa.v1".utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        let privateKey: SecKey
        if status == errSecSuccess, let result {
            privateKey = result as! SecKey
        } else if status == errSecItemNotFound {
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeySizeInBits as String: 2048,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String: true,
                    kSecAttrApplicationTag as String: tag,
                    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                ]
            ]
            var error: Unmanaged<CFError>?
            guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
                if let error { throw error.takeRetainedValue() }
                throw RemoteError.message("Could not create the ADB key.")
            }
            privateKey = key
        } else {
            throw RemoteError.message("Keychain error \(status). Unlock the phone and retry.")
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw RemoteError.message("Could not read the ADB public key.")
        }
        return KeyPair(privateKey: privateKey, publicKey: publicKey)
    }
}

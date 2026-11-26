import CryptoKit
import Foundation
import Security

struct LampIdentity: Sendable, Equatable {
    static let transferMagic: [UInt8] = [0x4C, 0x01]

    let privateKey: P256.Signing.PrivateKey

    static func == (lhs: LampIdentity, rhs: LampIdentity) -> Bool {
        lhs.privateKey.rawRepresentation == rhs.privateKey.rawRepresentation
    }

    init(privateKey: P256.Signing.PrivateKey = P256.Signing.PrivateKey()) {
        self.privateKey = privateKey
    }

    init?(transferMessage message: [UInt8]) {
        guard message.count == Self.transferMagic.count + 32,
              Array(message.prefix(Self.transferMagic.count)) == Self.transferMagic,
              let key = try? P256.Signing.PrivateKey(rawRepresentation: message.dropFirst(Self.transferMagic.count)) else {
            return nil
        }
        privateKey = key
    }

    var transferMessage: [UInt8] { Self.transferMagic + [UInt8](privateKey.rawRepresentation) }

    var contributorID: String {
        Self.base64URL(SHA256.hash(data: privateKey.publicKey.x963Representation).prefix(16))
    }

    var deletionCode: String {
        let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: privateKey.rawRepresentation),
                                         salt: Data("LAMP1".utf8), info: Data("deletion-code".utf8), outputByteCount: 16)
        let code = key.withUnsafeBytes { Self.crockfordBase32([UInt8]($0)) }
        return stride(from: 0, to: code.count, by: 4).map { start in
            let lower = code.index(code.startIndex, offsetBy: start)
            return String(code[lower..<code.index(lower, offsetBy: min(4, code.count - start))])
        }.joined(separator: "-")
    }

    static func base64URL<D: Sequence>(_ bytes: D) -> String where D.Element == UInt8 {
        Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func crockfordBase32(_ bytes: [UInt8]) -> String {
        let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        var result = "", buffer = 0, bits = 0
        for byte in bytes {
            buffer = buffer << 8 | Int(byte)
            bits += 8
            while bits >= 5 {
                result.append(alphabet[(buffer >> (bits - 5)) & 31])
                bits -= 5
            }
        }
        if bits > 0 { result.append(alphabet[(buffer << (5 - bits)) & 31]) }
        return result
    }
}

enum LampKeychain {
    private static let service = "com.tsubuzaki.DJDX.Lamp"
    private static let account = "ContributorKey"

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: kCFBooleanTrue as Any]
    }

    static func load() -> LampIdentity? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = try? P256.Signing.PrivateKey(rawRepresentation: data) else { return nil }
        return LampIdentity(privateKey: key)
    }

    @discardableResult
    static func save(_ identity: LampIdentity) -> Bool {
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = identity.privateKey.rawRepresentation
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
}

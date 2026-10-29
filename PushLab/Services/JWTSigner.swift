import Foundation
import CryptoKit

enum JWTSigner {
    /// Builds an ES256 provider token as described in "Establishing a token-based connection to APNs".
    static func es256Token(teamId: String, keyId: String, pem: String, issuedAt: Date = Date()) throws -> String {
        let privateKey: P256.Signing.PrivateKey
        do {
            privateKey = try P256.Signing.PrivateKey(pemRepresentation: normalizePEM(pem))
        } catch {
            throw InputError.invalidKeyFile
        }

        let header: [String: Any] = ["alg": "ES256", "kid": keyId, "typ": "JWT"]
        let claims: [String: Any] = ["iss": teamId, "iat": Int(issuedAt.timeIntervalSince1970)]
        let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
        let claimsData = try JSONSerialization.data(withJSONObject: claims, options: [.sortedKeys])
        let signingInput = headerData.base64URLEncoded + "." + claimsData.base64URLEncoded
        let signature = try privateKey.signature(for: Data(signingInput.utf8))
        return signingInput + "." + signature.rawRepresentation.base64URLEncoded
    }

    /// Accepts a full PEM file, a PEM without line breaks, or just the base64 body.
    static func normalizePEM(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("-----BEGIN") {
            let body = trimmed
                .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
                .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
                .replacingOccurrences(of: "-----BEGIN EC PRIVATE KEY-----", with: "")
                .replacingOccurrences(of: "-----END EC PRIVATE KEY-----", with: "")
            if trimmed.contains("EC PRIVATE KEY") {
                return "-----BEGIN EC PRIVATE KEY-----\n" + wrap(body) + "\n-----END EC PRIVATE KEY-----"
            }
            return "-----BEGIN PRIVATE KEY-----\n" + wrap(body) + "\n-----END PRIVATE KEY-----"
        }
        return "-----BEGIN PRIVATE KEY-----\n" + wrap(trimmed) + "\n-----END PRIVATE KEY-----"
    }

    private static func wrap(_ body: String) -> String {
        let compact = body.filter { !$0.isWhitespace }
        var lines: [String] = []
        var index = compact.startIndex
        while index < compact.endIndex {
            let end = compact.index(index, offsetBy: 64, limitedBy: compact.endIndex) ?? compact.endIndex
            lines.append(String(compact[index..<end]))
            index = end
        }
        return lines.joined(separator: "\n")
    }
}

/// Caches provider tokens per key. APNs asks for a refresh at least every hour and no more often than every 20 minutes.
final class JWTProvider {
    private struct CacheKey: Hashable {
        let teamId: String
        let keyId: String
        let keyDigest: String
    }

    private struct Entry {
        let token: String
        let createdAt: Date
    }

    private var cache: [CacheKey: Entry] = [:]
    private let lock = NSLock()
    private let lifetime: TimeInterval = 50 * 60

    func token(for auth: KeyAuthentication) throws -> String {
        guard let pem = auth.keyContent, !pem.isEmpty else { throw InputError.emptyKeyFile }
        let teamId = auth.teamId.trimmingCharacters(in: .whitespaces)
        let keyId = auth.keyId.trimmingCharacters(in: .whitespaces)
        let digest = SHA256.hash(data: Data(pem.utf8)).map { String(format: "%02x", $0) }.joined()
        let key = CacheKey(teamId: teamId, keyId: keyId, keyDigest: digest)

        lock.lock(); defer { lock.unlock() }
        if let entry = cache[key], Date().timeIntervalSince(entry.createdAt) < lifetime {
            return entry.token
        }
        let token = try JWTSigner.es256Token(teamId: teamId, keyId: keyId, pem: pem)
        cache[key] = Entry(token: token, createdAt: Date())
        return token
    }

    func invalidate() {
        lock.lock(); defer { lock.unlock() }
        cache.removeAll()
    }
}

extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

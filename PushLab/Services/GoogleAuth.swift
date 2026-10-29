import Foundation
import Security

enum FCMError: LocalizedError {
    case invalidServiceAccount(String)
    case authentication(String)
    case invalidMessage(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidServiceAccount(let detail): return "The service account is not usable: \(detail)"
        case .authentication(let detail): return "Google did not issue an access token: \(detail)"
        case .invalidMessage(let detail): return "The message is not a JSON object: \(detail)"
        case .invalidResponse: return "FCM returned a response that could not be read."
        }
    }
}

/// RS256 (RSASSA-PKCS1-v1_5 with SHA-256) using the Security framework, since CryptoKit has no RSA.
enum RS256Signer {
    static func privateKey(fromPEM pem: String) throws -> SecKey {
        let der = try DER.pkcs1RSAPrivateKey(fromPEM: pem)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, &error) else {
            let detail = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? "unreadable RSA key"
            throw FCMError.invalidServiceAccount(detail)
        }
        return key
    }

    static func sign(_ data: Data, pem: String) throws -> Data {
        let key = try privateKey(fromPEM: pem)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256, data as CFData, &error) else {
            let detail = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? "signing failed"
            throw FCMError.invalidServiceAccount(detail)
        }
        return signature as Data
    }
}

/// Just enough DER to unwrap a PKCS#8 PrivateKeyInfo into the PKCS#1 RSAPrivateKey that SecKey wants.
enum DER {
    struct Element {
        let tag: UInt8
        let content: Range<Int>
    }

    static func pkcs1RSAPrivateKey(fromPEM pem: String) throws -> Data {
        let body = pem
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") }
            .joined()
            .filter { !$0.isWhitespace }
        guard let der = Data(base64Encoded: body) else {
            throw FCMError.invalidServiceAccount("private_key is not valid PEM")
        }
        if pem.contains("BEGIN RSA PRIVATE KEY") { return der }

        // PKCS#8: SEQUENCE { INTEGER version, SEQUENCE algorithm, OCTET STRING privateKey }
        let bytes = [UInt8](der)
        let outer = try element(in: bytes, at: 0)
        guard outer.tag == 0x30 else { throw FCMError.invalidServiceAccount("private_key is not a PKCS#8 key") }
        var offset = outer.content.lowerBound
        while offset < outer.content.upperBound {
            let child = try element(in: bytes, at: offset)
            if child.tag == 0x04 {
                return Data(bytes[child.content])
            }
            offset = child.content.upperBound
        }
        throw FCMError.invalidServiceAccount("private_key has no RSA key inside")
    }

    static func element(in bytes: [UInt8], at offset: Int) throws -> Element {
        guard offset + 2 <= bytes.count else { throw FCMError.invalidServiceAccount("truncated DER") }
        let tag = bytes[offset]
        var cursor = offset + 2
        var length = Int(bytes[offset + 1])
        if length & 0x80 != 0 {
            let count = length & 0x7f
            guard count > 0, count <= 4, cursor + count <= bytes.count else { throw FCMError.invalidServiceAccount("bad DER length") }
            length = 0
            for _ in 0..<count {
                length = (length << 8) | Int(bytes[cursor])
                cursor += 1
            }
        }
        guard cursor + length <= bytes.count else { throw FCMError.invalidServiceAccount("truncated DER element") }
        return Element(tag: tag, content: cursor..<(cursor + length))
    }
}

/// Exchanges a service-account JWT for an OAuth 2.0 access token and caches it until shortly before expiry.
final class GoogleOAuthProvider {
    static let scope = "https://www.googleapis.com/auth/firebase.messaging"

    private struct Token {
        let value: String
        let expiresAt: Date
    }

    private var cache: [String: Token] = [:]
    private let lock = NSLock()

    func accessToken(for account: GoogleServiceAccount) async throws -> String {
        let cacheKey = account.clientEmail + "|" + (account.privateKeyId ?? "")
        if let cached = cachedToken(for: cacheKey), cached.expiresAt > Date().addingTimeInterval(60) {
            return cached.value
        }

        let assertion = try Self.assertion(for: account)
        var request = URLRequest(url: account.tokenURL, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
        request.httpBody = Data("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(assertion)".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, let token = json?["access_token"] as? String else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let detail = json?["error_description"] as? String ?? json?["error"] as? String ?? "HTTP \(status)"
            throw FCMError.authentication(detail)
        }
        let lifetime = (json?["expires_in"] as? Double) ?? 3600
        store(Token(value: token, expiresAt: Date().addingTimeInterval(lifetime)), for: cacheKey)
        return token
    }

    private func cachedToken(for key: String) -> Token? {
        lock.lock(); defer { lock.unlock() }
        return cache[key]
    }

    private func store(_ token: Token, for key: String) {
        lock.lock(); defer { lock.unlock() }
        cache[key] = token
    }

    func invalidate() {
        lock.lock(); defer { lock.unlock() }
        cache.removeAll()
    }

    static func assertion(for account: GoogleServiceAccount, now: Date = Date()) throws -> String {
        var header: [String: Any] = ["alg": "RS256", "typ": "JWT"]
        if let kid = account.privateKeyId, !kid.isEmpty { header["kid"] = kid }
        let issued = Int(now.timeIntervalSince1970)
        let claims: [String: Any] = [
            "iss": account.clientEmail,
            "scope": scope,
            "aud": account.tokenURL.absoluteString,
            "iat": issued,
            "exp": issued + 3600
        ]
        let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
        let claimsData = try JSONSerialization.data(withJSONObject: claims, options: [.sortedKeys])
        let signingInput = headerData.base64URLEncoded + "." + claimsData.base64URLEncoded
        let signature = try RS256Signer.sign(Data(signingInput.utf8), pem: account.privateKey)
        return signingInput + "." + signature.base64URLEncoded
    }
}

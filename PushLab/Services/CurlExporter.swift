import Foundation

enum CurlExporter {
    static func command(for input: PushInput) -> String {
        let token = input.deviceTokens.first ?? "<device token>"
        let url = input.environment.baseURL.appendingPathComponent(token).absoluteString
        var parts: [String] = ["curl -v --http2"]

        switch input.authentication {
        case .key:
            let auth = input.keyAuthentication
            let jwt: String
            if let pem = auth.keyContent, let signed = try? JWTSigner.es256Token(teamId: auth.teamId, keyId: auth.keyId, pem: pem) {
                jwt = signed
            } else {
                jwt = "<provider token>"
            }
            parts.append("--header \"authorization: bearer \(jwt)\"")
        case .certificate:
            let path = input.certificateAuthentication.file?.url?.path ?? "<certificate.p12>"
            let pass = input.certificateAuthentication.passphrase
            parts.append("--cert-type P12 --cert \"\(path)\(pass.isEmpty ? "" : ":" + pass)\"")
        case .keychain:
            parts.append("--cert \"\(input.keychainAuthentication.identityLabel)\"")
        }

        parts.append("--header \"apns-topic: \(input.topic)\"")
        parts.append("--header \"apns-push-type: \(input.pushType.rawValue)\"")
        parts.append("--header \"apns-priority: \(input.priority.headerValue)\"")
        let expiration = input.expiration.trimmingCharacters(in: .whitespaces)
        if !expiration.isEmpty { parts.append("--header \"apns-expiration: \(expiration)\"") }
        let collapse = input.collapseId.trimmingCharacters(in: .whitespaces)
        if !collapse.isEmpty { parts.append("--header \"apns-collapse-id: \(collapse)\"") }
        let notificationId = input.notificationId.trimmingCharacters(in: .whitespaces)
        if !notificationId.isEmpty { parts.append("--header \"apns-id: \(notificationId)\"") }
        parts.append("--header \"content-type: application/json\"")

        let body = input.message.replacingOccurrences(of: "'", with: "'\\''")
        parts.append("--data '\(body)'")
        parts.append("\"\(url)\"")
        return parts.joined(separator: " \\\n  ")
    }
}

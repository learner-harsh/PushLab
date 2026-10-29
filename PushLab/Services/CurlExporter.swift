import Foundation

enum CurlExporter {
    static func command(for input: PushInput) -> String {
        switch input.platform {
        case .apns: return apnsCommand(for: input)
        case .fcm: return fcmCommand(for: input)
        }
    }

    static func fcmCommand(for input: PushInput) -> String {
        let fcm = input.fcm
        let projectId = fcm.serviceAccount?.projectId ?? "<project id>"
        let target = fcm.targets.first ?? "<\(fcm.targetKind.rawValue)>"
        let bodyText: String
        if let data = try? FCMClient.requestBody(for: fcm, target: target), let text = String(data: data, encoding: .utf8) {
            bodyText = text
        } else {
            bodyText = "{ \"message\": { \"\(fcm.targetKind.rawValue)\": \"\(target)\" } }"
        }
        let body = bodyText.replacingOccurrences(of: "'", with: "'\\''")
        let accountPath = fcm.serviceAccountFile?.url?.path ?? "<service-account.json>"
        let curl = [
            "curl -v -X POST",
            "--header \"authorization: Bearer $(gcloud auth print-access-token)\"",
            "--header \"content-type: application/json; charset=UTF-8\"",
            "--data '\(body)'",
            "\"https://fcm.googleapis.com/v1/projects/\(projectId)/messages:send\""
        ].joined(separator: " \\\n  ")
        return """
        # Mint an access token with the same service account first:
        # gcloud auth activate-service-account --key-file="\(accountPath)"
        \(curl)
        """
    }

    static func apnsCommand(for input: PushInput) -> String {
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

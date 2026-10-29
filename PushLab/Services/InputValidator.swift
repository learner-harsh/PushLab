import Foundation

enum InputError: LocalizedError, Equatable, Identifiable {
    case emptyBundleId
    case emptyTeamId
    case emptyKeyId
    case emptyKeyFile
    case invalidKeyFile
    case emptyCertFile
    case invalidCertFileOrPassphrase
    case noKeychainIdentity
    case emptyMessage
    case invalidMessage(String)
    case emptyDeviceToken
    case invalidDeviceToken(String)
    case invalidExpiration
    case invalidNotificationId

    var id: String { errorDescription ?? "" }

    var errorDescription: String? {
        switch self {
        case .emptyBundleId: return "Check that bundle id is not empty"
        case .emptyTeamId: return "Check that team id is not empty"
        case .emptyKeyId: return "Check that key id is not empty"
        case .emptyKeyFile: return "Check that a .p8 key file is selected or its content is pasted"
        case .invalidKeyFile: return "Check that the .p8 key file contains a valid P-256 private key"
        case .emptyCertFile: return "Check that a .p12 certificate file is selected"
        case .invalidCertFileOrPassphrase: return "Check that certificate file and passphrase are correct"
        case .noKeychainIdentity: return "Check that a push certificate is selected from Keychain"
        case .emptyMessage: return "Check that message is not empty"
        case .invalidMessage(let detail): return "Check that message contains valid JSON payload: \(detail)"
        case .emptyDeviceToken: return "Check that device tokens are not empty"
        case .invalidDeviceToken(let token): return "Check that device tokens are valid hexadecimal strings (\(token))"
        case .invalidExpiration: return "Check that expiration is either 0 or a UNIX epoch expressed in seconds"
        case .invalidNotificationId: return "Check that notification id is a canonical UUID (8-4-4-4-12)"
        }
    }
}

enum NetworkError: LocalizedError {
    case invalidRequest
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidRequest: return "The request could not be built."
        case .invalidResponse: return "APNs returned a response that could not be read."
        }
    }
}

enum InputValidator {
    static func validate(_ input: PushInput) -> [InputError] {
        var errors: [InputError] = []

        if input.topic.isEmpty { errors.append(.emptyBundleId) }

        switch input.authentication {
        case .key:
            if input.keyAuthentication.teamId.trimmingCharacters(in: .whitespaces).isEmpty { errors.append(.emptyTeamId) }
            if input.keyAuthentication.keyId.trimmingCharacters(in: .whitespaces).isEmpty { errors.append(.emptyKeyId) }
            if input.keyAuthentication.keyContent == nil { errors.append(.emptyKeyFile) }
        case .certificate:
            if input.certificateAuthentication.file?.data == nil { errors.append(.emptyCertFile) }
        case .keychain:
            if input.keychainAuthentication.identityLabel.isEmpty { errors.append(.noKeychainIdentity) }
        }

        let message = input.message.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty {
            errors.append(.emptyMessage)
        } else if let problem = jsonProblem(in: message) {
            errors.append(.invalidMessage(problem))
        }

        let tokens = input.deviceTokens
        if tokens.isEmpty {
            errors.append(.emptyDeviceToken)
        } else {
            let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            for token in tokens where token.rangeOfCharacter(from: hex.inverted) != nil || token.count < 32 {
                errors.append(.invalidDeviceToken(token))
                break
            }
        }

        let expiration = input.expiration.trimmingCharacters(in: .whitespaces)
        if !expiration.isEmpty, Int(expiration) == nil || Int(expiration)! < 0 {
            errors.append(.invalidExpiration)
        }

        let notificationId = input.notificationId.trimmingCharacters(in: .whitespaces)
        if !notificationId.isEmpty, UUID(uuidString: notificationId) == nil {
            errors.append(.invalidNotificationId)
        }

        return errors
    }

    /// Returns a human readable description of the first JSON syntax problem, or nil when the text is a JSON object.
    static func jsonProblem(in text: String) -> String? {
        let data = Data(text.utf8)
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [])
            if object is [String: Any] { return nil }
            return "payload must be a JSON object"
        } catch let error as NSError {
            if let debug = error.userInfo[NSDebugDescriptionErrorKey] as? String {
                return debug
            }
            return error.localizedDescription
        }
    }

    static func prettyPrinted(_ text: String) -> String? {
        let data = Data(text.utf8)
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let string = String(data: pretty, encoding: .utf8) else { return nil }
        return string
    }
}

import Foundation

enum APNsEnvironment: String, Codable, CaseIterable, Identifiable {
    case sandbox
    case production

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sandbox: return "Sandbox"
        case .production: return "Production"
        }
    }

    var host: String {
        switch self {
        case .sandbox: return "api.sandbox.push.apple.com"
        case .production: return "api.push.apple.com"
        }
    }

    var baseURL: URL { URL(string: "https://\(host):443/3/device/")! }
}

enum AuthenticationMethod: String, Codable, CaseIterable, Identifiable {
    case key
    case certificate
    case keychain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .key: return "Key (.p8)"
        case .certificate: return "Certificate (.p12)"
        case .keychain: return "Keychain"
        }
    }

    var symbol: String {
        switch self {
        case .key: return "key.fill"
        case .certificate: return "doc.badge.gearshape"
        case .keychain: return "lock.shield"
        }
    }
}

enum PushType: String, Codable, CaseIterable, Identifiable {
    case alert
    case background
    case location
    case voip
    case complication
    case fileprovider
    case mdm
    case liveactivity
    case pushtotalk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alert: return "Alert"
        case .background: return "Background"
        case .location: return "Location"
        case .voip: return "VoIP"
        case .complication: return "Complication"
        case .fileprovider: return "File Provider"
        case .mdm: return "MDM"
        case .liveactivity: return "Live Activity"
        case .pushtotalk: return "Push to Talk"
        }
    }

    /// Suffix APNs expects appended to the app bundle identifier in `apns-topic`.
    var topicSuffix: String? {
        switch self {
        case .alert, .background, .mdm: return nil
        case .location: return ".location-query"
        case .voip: return ".voip"
        case .complication: return ".complication"
        case .fileprovider: return ".pushkit.fileprovider"
        case .liveactivity: return ".push-type.liveactivity"
        case .pushtotalk: return ".voip-ptt"
        }
    }

    var summary: String {
        switch self {
        case .alert:
            return "Use the alert push type for notifications that trigger a user interaction, for example an alert, badge, or sound."
        case .background:
            return "Use the background push type for notifications that deliver content in the background and don't trigger any user interactions. Set apns-priority to 5 and include content-available: 1."
        case .location:
            return "Use the location push type for notifications that request a user's location. The topic must be <bundle id>.location-query."
        case .voip:
            return "Use the voip push type for notifications that provide information about an incoming Voice-over-IP call. The topic must be <bundle id>.voip."
        case .complication:
            return "Use the complication push type for notifications that contain update information for a watchOS app's complications. The topic must be <bundle id>.complication."
        case .fileprovider:
            return "Use the fileprovider push type to signal changes to a File Provider extension. The topic must be <bundle id>.pushkit.fileprovider."
        case .mdm:
            return "Use the mdm push type for notifications that tell managed devices to contact the MDM server. The topic is the MDM push certificate UID."
        case .liveactivity:
            return "Use the liveactivity push type to start, update, or end a Live Activity. The topic must be <bundle id>.push-type.liveactivity."
        case .pushtotalk:
            return "Use the pushtotalk push type for notifications that provide information about updates to your application's push to talk services. The topic must be <bundle id>.voip-ptt."
        }
    }
}

enum PushPriority: String, Codable, CaseIterable, Identifiable {
    case immediate
    case conserve
    case low

    var id: String { rawValue }

    var headerValue: String {
        switch self {
        case .immediate: return "10"
        case .conserve: return "5"
        case .low: return "1"
        }
    }

    var title: String {
        switch self {
        case .immediate: return "10 · Immediately"
        case .conserve: return "5 · Power considerations"
        case .low: return "1 · Prioritize device power"
        }
    }
}

/// A file the user picked. The bytes are kept so the template keeps working after relaunch.
struct FileReference: Codable, Equatable {
    var url: URL?
    var data: Data?

    var name: String { url?.lastPathComponent ?? "" }
}

struct KeyAuthentication: Codable, Equatable {
    var file: FileReference?
    var teamId: String = ""
    var keyId: String = ""
    /// PEM content of the .p8 key, either read from `file` or pasted directly.
    var cachedContent: String?

    var keyContent: String? {
        if let cachedContent, !cachedContent.isEmpty { return cachedContent }
        if let data = file?.data, let text = String(data: data, encoding: .utf8) { return text }
        return nil
    }
}

struct CertificateAuthentication: Codable, Equatable {
    var file: FileReference?
    var passphrase: String = ""
}

struct KeychainAuthentication: Codable, Equatable {
    var identityLabel: String = ""
}

struct PushInput: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var bundleId: String = ""
    var message: String = PayloadPresets.defaultMessage
    var environment: APNsEnvironment = .sandbox
    var authentication: AuthenticationMethod = .key
    var keyAuthentication = KeyAuthentication()
    var certificateAuthentication = CertificateAuthentication()
    var keychainAuthentication = KeychainAuthentication()
    var collapseId: String = ""
    var pushType: PushType = .alert
    var priority: PushPriority = .immediate
    var deviceToken: String = ""
    var notificationId: String = ""
    var expiration: String = ""
    var platform: PushPlatform = .apns
    var fcm = FCMInput()

    init() {}

    /// Tolerant decoding so templates saved by older versions keep loading when fields are added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PushInput()
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bundleId = try c.decodeIfPresent(String.self, forKey: .bundleId) ?? defaults.bundleId
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? defaults.message
        environment = try c.decodeIfPresent(APNsEnvironment.self, forKey: .environment) ?? defaults.environment
        authentication = try c.decodeIfPresent(AuthenticationMethod.self, forKey: .authentication) ?? defaults.authentication
        keyAuthentication = try c.decodeIfPresent(KeyAuthentication.self, forKey: .keyAuthentication) ?? defaults.keyAuthentication
        certificateAuthentication = try c.decodeIfPresent(CertificateAuthentication.self, forKey: .certificateAuthentication) ?? defaults.certificateAuthentication
        keychainAuthentication = try c.decodeIfPresent(KeychainAuthentication.self, forKey: .keychainAuthentication) ?? defaults.keychainAuthentication
        collapseId = try c.decodeIfPresent(String.self, forKey: .collapseId) ?? ""
        pushType = try c.decodeIfPresent(PushType.self, forKey: .pushType) ?? defaults.pushType
        priority = try c.decodeIfPresent(PushPriority.self, forKey: .priority) ?? defaults.priority
        deviceToken = try c.decodeIfPresent(String.self, forKey: .deviceToken) ?? ""
        notificationId = try c.decodeIfPresent(String.self, forKey: .notificationId) ?? ""
        expiration = try c.decodeIfPresent(String.self, forKey: .expiration) ?? ""
        platform = try c.decodeIfPresent(PushPlatform.self, forKey: .platform) ?? .apns
        fcm = try c.decodeIfPresent(FCMInput.self, forKey: .fcm) ?? FCMInput()
    }

    /// What the sidebar shows under the template name.
    var subtitle: String {
        switch platform {
        case .apns: return bundleId.isEmpty ? "No bundle id" : bundleId
        case .fcm: return fcm.serviceAccount?.projectId ?? "No service account"
        }
    }

    /// Device tokens split on newlines, commas, and whitespace.
    var deviceTokens: [String] {
        deviceToken
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var topic: String { bundleId.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// True when the push type needs a topic suffix that the current topic does not carry.
    var topicNeedsSuffix: Bool {
        guard let suffix = pushType.topicSuffix else { return false }
        return !topic.isEmpty && !topic.hasSuffix(suffix)
    }
}

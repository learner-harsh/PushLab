import Foundation

enum PushPlatform: String, Codable, CaseIterable, Identifiable {
    case apns
    case fcm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apns: return "Apple · APNs"
        case .fcm: return "Android · FCM"
        }
    }

    var shortTitle: String {
        switch self {
        case .apns: return "APNs"
        case .fcm: return "FCM"
        }
    }

    var symbol: String {
        switch self {
        case .apns: return "apple.logo"
        case .fcm: return "flame.fill"
        }
    }
}

enum FCMTargetKind: String, Codable, CaseIterable, Identifiable {
    case token
    case topic
    case condition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .token: return "Device token"
        case .topic: return "Topic"
        case .condition: return "Condition"
        }
    }

    var prompt: String {
        switch self {
        case .token: return "One or more FCM registration tokens"
        case .topic: return "news"
        case .condition: return "'news' in topics && ('android' in topics || 'ios' in topics)"
        }
    }
}

/// The fields PushLab needs from a Firebase service-account JSON file.
struct GoogleServiceAccount: Codable, Equatable {
    var type: String?
    var projectId: String
    var privateKeyId: String?
    var privateKey: String
    var clientEmail: String
    var tokenUri: String?

    enum CodingKeys: String, CodingKey {
        case type
        case projectId = "project_id"
        case privateKeyId = "private_key_id"
        case privateKey = "private_key"
        case clientEmail = "client_email"
        case tokenUri = "token_uri"
    }

    var tokenURL: URL {
        URL(string: tokenUri ?? "") ?? URL(string: "https://oauth2.googleapis.com/token")!
    }

    var sendURL: URL {
        URL(string: "https://fcm.googleapis.com/v1/projects/\(projectId)/messages:send")!
    }

    static func parse(_ data: Data) -> GoogleServiceAccount? {
        guard let account = try? JSONDecoder().decode(GoogleServiceAccount.self, from: data) else { return nil }
        guard !account.projectId.isEmpty, !account.clientEmail.isEmpty, !account.privateKey.isEmpty else { return nil }
        return account
    }
}

struct FCMInput: Codable, Equatable {
    var serviceAccountFile: FileReference?
    var targetKind: FCMTargetKind = .token
    var target: String = ""
    /// The FCM `message` object as JSON, without the target key. The target is added at send time.
    var message: String = FCMPresets.defaultMessage
    var validateOnly: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serviceAccountFile = try container.decodeIfPresent(FileReference.self, forKey: .serviceAccountFile)
        targetKind = try container.decodeIfPresent(FCMTargetKind.self, forKey: .targetKind) ?? .token
        target = try container.decodeIfPresent(String.self, forKey: .target) ?? ""
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? FCMPresets.defaultMessage
        validateOnly = try container.decodeIfPresent(Bool.self, forKey: .validateOnly) ?? false
    }

    var serviceAccount: GoogleServiceAccount? {
        serviceAccountFile?.data.flatMap(GoogleServiceAccount.parse)
    }

    /// Tokens are split like APNs device tokens. A topic or condition is a single target.
    var targets: [String] {
        switch targetKind {
        case .token:
            return target
                .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;")))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        case .topic, .condition:
            let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
    }
}

/// FCM v1 error codes (google.firebase.fcm.v1.FcmError) and the google.rpc statuses that wrap them.
enum FCMErrorCode: String, CaseIterable {
    case UNSPECIFIED_ERROR, INVALID_ARGUMENT, UNREGISTERED, SENDER_ID_MISMATCH, QUOTA_EXCEEDED
    case UNAVAILABLE, INTERNAL, THIRD_PARTY_AUTH_ERROR
    case PERMISSION_DENIED, UNAUTHENTICATED, NOT_FOUND, RESOURCE_EXHAUSTED

    var explanation: String {
        switch self {
        case .UNSPECIFIED_ERROR: return "No more information is available about this error."
        case .INVALID_ARGUMENT: return "Request parameters were invalid. Check the registration token, the message fields, and that the payload is under 4096 bytes. The error message usually names the bad field."
        case .UNREGISTERED: return "The app instance was unregistered from FCM. This usually means the token used is no longer valid and a new one must be used; stop sending to this token."
        case .SENDER_ID_MISMATCH: return "The authenticated sender ID is different from the sender ID for the registration token. A registration token is tied to a Firebase project, so this service account belongs to a different project than the app that generated the token."
        case .QUOTA_EXCEEDED: return "Sending limit exceeded for the message target. Retry with exponential backoff; the Retry-After header suggests a delay."
        case .UNAVAILABLE: return "The server is overloaded. Retry with exponential backoff and honor the Retry-After header."
        case .INTERNAL: return "An unknown internal error occurred. Retry the request; if it persists, contact Firebase support."
        case .THIRD_PARTY_AUTH_ERROR: return "APNs certificate or web push auth key was invalid or missing. A message targeted to an iOS device or a web push registration could not be sent. Check the APNs credentials in the Firebase console."
        case .PERMISSION_DENIED: return "The service account is not allowed to send messages for this project. Grant it the Firebase Cloud Messaging API Admin role, and make sure the Firebase Cloud Messaging API (V1) is enabled in Google Cloud."
        case .UNAUTHENTICATED: return "The access token is missing, expired, or not valid for this project. Re-check the service-account JSON file."
        case .NOT_FOUND: return "The project or the registration token was not found. Verify the project id in the service account and that the token belongs to this project."
        case .RESOURCE_EXHAUSTED: return "Quota exceeded. Retry with exponential backoff."
        }
    }

    static func explanation(for code: String) -> String? {
        FCMErrorCode(rawValue: code)?.explanation
    }
}

struct FCMPreset: Identifiable, Hashable {
    let name: String
    let json: String
    var id: String { name }
}

enum FCMPresets {
    static let defaultMessage = """
    {
       "notification" : {
          "title" : "PushLab",
          "body" : "Test push notification"
       }
    }
    """

    static let all: [FCMPreset] = [
        FCMPreset(name: "Notification", json: defaultMessage),
        FCMPreset(name: "Notification with data", json: """
        {
           "notification" : {
              "title" : "New message",
              "body" : "You have a new message"
           },
           "data" : {
              "screen" : "chat",
              "chatId" : "42"
           }
        }
        """),
        FCMPreset(name: "Data only (silent)", json: """
        {
           "data" : {
              "type" : "sync",
              "reason" : "manual-test"
           },
           "android" : {
              "priority" : "high"
           }
        }
        """),
        FCMPreset(name: "Android high priority, TTL, channel", json: """
        {
           "notification" : {
              "title" : "Order update",
              "body" : "Your order is on the way"
           },
           "android" : {
              "priority" : "high",
              "ttl" : "3600s",
              "collapse_key" : "order-1234",
              "notification" : {
                 "channel_id" : "default",
                 "sound" : "default",
                 "color" : "#3579F4",
                 "click_action" : "OPEN_ORDER",
                 "tag" : "order-1234"
              }
           }
        }
        """),
        FCMPreset(name: "Image notification", json: """
        {
           "notification" : {
              "title" : "Picture",
              "body" : "A notification with an image",
              "image" : "https://picsum.photos/600/300"
           },
           "android" : {
              "notification" : {
                 "image" : "https://picsum.photos/600/300"
              }
           }
        }
        """),
        FCMPreset(name: "Localized Android notification", json: """
        {
           "android" : {
              "priority" : "high",
              "notification" : {
                 "title_loc_key" : "notification_title",
                 "body_loc_key" : "notification_body",
                 "body_loc_args" : [ "Harsh", "3" ]
              }
           }
        }
        """),
        FCMPreset(name: "Multi-platform (Android + iOS + Web)", json: """
        {
           "notification" : {
              "title" : "Hello everywhere",
              "body" : "Platform-specific overrides below"
           },
           "android" : {
              "priority" : "high",
              "notification" : { "channel_id" : "default" }
           },
           "apns" : {
              "headers" : { "apns-priority" : "10" },
              "payload" : {
                 "aps" : { "badge" : 1, "sound" : "default" }
              }
           },
           "webpush" : {
              "headers" : { "Urgency" : "high" },
              "notification" : { "icon" : "https://example.com/icon.png" }
           }
        }
        """),
        FCMPreset(name: "iOS via FCM (APNs override)", json: """
        {
           "notification" : {
              "title" : "Via FCM",
              "body" : "Delivered to APNs through Firebase"
           },
           "apns" : {
              "headers" : {
                 "apns-priority" : "10",
                 "apns-push-type" : "alert"
              },
              "payload" : {
                 "aps" : {
                    "sound" : "default",
                    "mutable-content" : 1
                 }
              }
           }
        }
        """),
        FCMPreset(name: "Analytics label", json: """
        {
           "notification" : {
              "title" : "Campaign",
              "body" : "Tracked in Firebase analytics"
           },
           "fcm_options" : {
              "analytics_label" : "pushlab-test"
           }
        }
        """)
    ]
}

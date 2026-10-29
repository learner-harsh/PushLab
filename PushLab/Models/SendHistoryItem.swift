import Foundation

struct SendHistoryItem: Codable, Identifiable, Equatable, Hashable {
    struct KeyValue: Codable, Equatable, Hashable, Identifiable {
        var key: String
        var value: String
        var id: String { key + "=" + value }
    }

    var id: UUID = UUID()
    var number: Int
    var inputId: UUID
    var statusCode: Int
    var requestUrl: String
    var requestHeaders: [KeyValue]
    var requestMessage: String
    var responseHeaders: [KeyValue]
    var responseReasonCode: String?
    var responseData: String?
    var deviceToken: String
    var createdAt: Date = Date()
    var requestString: String
    var responseString: String
    var environment: APNsEnvironment
    var pushType: PushType
    var durationMs: Int = 0
    var localError: String?
    var platform: PushPlatform = .apns
    var fcmMessageName: String?
    var fcmErrorMessage: String?
    var projectId: String?

    init(id: UUID = UUID(), number: Int, inputId: UUID, statusCode: Int, requestUrl: String, requestHeaders: [KeyValue],
         requestMessage: String, responseHeaders: [KeyValue], responseReasonCode: String?, responseData: String?,
         deviceToken: String, createdAt: Date = Date(), requestString: String, responseString: String,
         environment: APNsEnvironment, pushType: PushType, durationMs: Int = 0, localError: String? = nil,
         platform: PushPlatform = .apns, fcmMessageName: String? = nil, fcmErrorMessage: String? = nil, projectId: String? = nil) {
        self.id = id
        self.number = number
        self.inputId = inputId
        self.statusCode = statusCode
        self.requestUrl = requestUrl
        self.requestHeaders = requestHeaders
        self.requestMessage = requestMessage
        self.responseHeaders = responseHeaders
        self.responseReasonCode = responseReasonCode
        self.responseData = responseData
        self.deviceToken = deviceToken
        self.createdAt = createdAt
        self.requestString = requestString
        self.responseString = responseString
        self.environment = environment
        self.pushType = pushType
        self.durationMs = durationMs
        self.localError = localError
        self.platform = platform
        self.fcmMessageName = fcmMessageName
        self.fcmErrorMessage = fcmErrorMessage
        self.projectId = projectId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        number = try c.decodeIfPresent(Int.self, forKey: .number) ?? 0
        inputId = try c.decode(UUID.self, forKey: .inputId)
        statusCode = try c.decodeIfPresent(Int.self, forKey: .statusCode) ?? 0
        requestUrl = try c.decodeIfPresent(String.self, forKey: .requestUrl) ?? ""
        requestHeaders = try c.decodeIfPresent([KeyValue].self, forKey: .requestHeaders) ?? []
        requestMessage = try c.decodeIfPresent(String.self, forKey: .requestMessage) ?? ""
        responseHeaders = try c.decodeIfPresent([KeyValue].self, forKey: .responseHeaders) ?? []
        responseReasonCode = try c.decodeIfPresent(String.self, forKey: .responseReasonCode)
        responseData = try c.decodeIfPresent(String.self, forKey: .responseData)
        deviceToken = try c.decodeIfPresent(String.self, forKey: .deviceToken) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        requestString = try c.decodeIfPresent(String.self, forKey: .requestString) ?? ""
        responseString = try c.decodeIfPresent(String.self, forKey: .responseString) ?? ""
        environment = try c.decodeIfPresent(APNsEnvironment.self, forKey: .environment) ?? .sandbox
        pushType = try c.decodeIfPresent(PushType.self, forKey: .pushType) ?? .alert
        durationMs = try c.decodeIfPresent(Int.self, forKey: .durationMs) ?? 0
        localError = try c.decodeIfPresent(String.self, forKey: .localError)
        platform = try c.decodeIfPresent(PushPlatform.self, forKey: .platform) ?? .apns
        fcmMessageName = try c.decodeIfPresent(String.self, forKey: .fcmMessageName)
        fcmErrorMessage = try c.decodeIfPresent(String.self, forKey: .fcmErrorMessage)
        projectId = try c.decodeIfPresent(String.self, forKey: .projectId)
    }

    var isSuccess: Bool { statusCode == 200 }

    var apnsId: String? {
        responseHeaders.first { $0.key.lowercased() == "apns-id" }?.value
    }

    var apnsUniqueId: String? {
        responseHeaders.first { $0.key.lowercased() == "apns-unique-id" }?.value
    }

    var reason: ReasonCode? {
        guard platform == .apns else { return nil }
        return responseReasonCode.flatMap(ReasonCode.init(rawValue:))
    }

    /// Human readable explanation of the failure, for either platform.
    var reasonExplanation: String? {
        switch platform {
        case .apns: return reason?.explanation
        case .fcm:
            let documented = responseReasonCode.flatMap(FCMErrorCode.explanation(for:))
            return [documented, fcmErrorMessage].compactMap { $0 }.joined(separator: "\n\n").nilIfEmpty
        }
    }

    /// Where the message went: APNs environment or the FCM project.
    var destinationTitle: String {
        switch platform {
        case .apns: return environment.title
        case .fcm: return projectId ?? "FCM"
        }
    }

    var statusTitle: String {
        if let localError { return localError }
        if isSuccess { return "Sent" }
        if let responseReasonCode { return "\(statusCode) \(responseReasonCode)" }
        return statusCode == 0 ? "Failed" : "\(statusCode)"
    }

    var shortToken: String {
        guard deviceToken.count > 12 else { return deviceToken }
        return String(deviceToken.prefix(6)) + "…" + String(deviceToken.suffix(6))
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

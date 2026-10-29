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

    var isSuccess: Bool { statusCode == 200 }

    var apnsId: String? {
        responseHeaders.first { $0.key.lowercased() == "apns-id" }?.value
    }

    var apnsUniqueId: String? {
        responseHeaders.first { $0.key.lowercased() == "apns-unique-id" }?.value
    }

    var reason: ReasonCode? {
        responseReasonCode.flatMap(ReasonCode.init(rawValue:))
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

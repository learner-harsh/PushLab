import Foundation
import Security

/// Sends one notification over HTTP/2 to APNs and captures the full exchange for the history view.
final class APNsClient {
    private let jwtProvider = JWTProvider()

    func send(input: PushInput, deviceToken: String, number: Int) async throws -> SendHistoryItem {
        let url = input.environment.baseURL.appendingPathComponent(deviceToken)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.httpBody = Data(input.message.utf8)

        var headers: [(String, String)] = [
            ("content-type", "application/json"),
            ("apns-topic", input.topic),
            ("apns-push-type", input.pushType.rawValue),
            ("apns-priority", input.priority.headerValue)
        ]
        let expiration = input.expiration.trimmingCharacters(in: .whitespaces)
        if !expiration.isEmpty { headers.append(("apns-expiration", expiration)) }
        let collapseId = input.collapseId.trimmingCharacters(in: .whitespaces)
        if !collapseId.isEmpty { headers.append(("apns-collapse-id", collapseId)) }
        let notificationId = input.notificationId.trimmingCharacters(in: .whitespaces)
        if !notificationId.isEmpty { headers.append(("apns-id", notificationId.lowercased())) }

        var identity: SecIdentity?
        switch input.authentication {
        case .key:
            let token = try jwtProvider.token(for: input.keyAuthentication)
            headers.append(("authorization", "bearer \(token)"))
        case .certificate:
            guard let data = input.certificateAuthentication.file?.data else { throw InputError.emptyCertFile }
            identity = try IdentityProvider.identity(fromP12: data, passphrase: input.certificateAuthentication.passphrase)
        case .keychain:
            identity = try IdentityProvider.identity(labelled: input.keychainAuthentication.identityLabel)
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let delegate = ClientCertificateDelegate(identity: identity)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let started = Date()
        let requestString = Self.describe(request: request, headers: headers, body: input.message)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
            let duration = Int(Date().timeIntervalSince(started) * 1000)
            let responseHeaders = http.allHeaderFields.compactMap { key, value -> SendHistoryItem.KeyValue? in
                guard let key = key as? String else { return nil }
                return SendHistoryItem.KeyValue(key: key, value: "\(value)")
            }.sorted { $0.key < $1.key }
            let body = String(data: data, encoding: .utf8) ?? ""
            let reason = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["reason"] as? String

            return SendHistoryItem(
                number: number,
                inputId: input.id,
                statusCode: http.statusCode,
                requestUrl: url.absoluteString,
                requestHeaders: headers.map { SendHistoryItem.KeyValue(key: $0.0, value: $0.1) },
                requestMessage: input.message,
                responseHeaders: responseHeaders,
                responseReasonCode: reason,
                responseData: body.isEmpty ? nil : body,
                deviceToken: deviceToken,
                requestString: requestString,
                responseString: Self.describe(response: http, body: body),
                environment: input.environment,
                pushType: input.pushType,
                durationMs: duration
            )
        } catch let error as URLError {
            let duration = Int(Date().timeIntervalSince(started) * 1000)
            return SendHistoryItem(
                number: number,
                inputId: input.id,
                statusCode: 0,
                requestUrl: url.absoluteString,
                requestHeaders: headers.map { SendHistoryItem.KeyValue(key: $0.0, value: $0.1) },
                requestMessage: input.message,
                responseHeaders: [],
                responseReasonCode: nil,
                responseData: nil,
                deviceToken: deviceToken,
                requestString: requestString,
                responseString: "No response. \(error.localizedDescription) (URLError \(error.code.rawValue))",
                environment: input.environment,
                pushType: input.pushType,
                durationMs: duration,
                localError: error.localizedDescription
            )
        }
    }

    private static func describe(request: URLRequest, headers: [(String, String)], body: String) -> String {
        var lines = ["POST \(request.url?.path ?? "") HTTP/2", "Host: \(request.url?.host ?? "")"]
        for (key, value) in headers { lines.append("\(key): \(value)") }
        lines.append("")
        lines.append(body)
        return lines.joined(separator: "\n")
    }

    private static func describe(response: HTTPURLResponse, body: String) -> String {
        var lines = ["HTTP/2 \(response.statusCode) \(ReasonCode.httpStatusTitle(response.statusCode))"]
        for (key, value) in response.allHeaderFields {
            lines.append("\(key): \(value)")
        }
        lines.append("")
        lines.append(body.isEmpty ? "(empty body)" : body)
        return lines.joined(separator: "\n")
    }
}

/// Answers the TLS client-certificate challenge with the selected identity.
final class ClientCertificateDelegate: NSObject, URLSessionDelegate {
    let identity: SecIdentity?

    init(identity: SecIdentity?) {
        self.identity = identity
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate, let identity {
            let credential = URLCredential(identity: identity, certificates: nil, persistence: .forSession)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

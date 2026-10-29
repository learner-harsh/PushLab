import Foundation

/// Sends one message through the FCM HTTP v1 API and records the exchange for the history view.
final class FCMClient {
    static let payloadLimit = 4096

    let oauth = GoogleOAuthProvider()

    func send(input: PushInput, target: String, number: Int) async throws -> SendHistoryItem {
        guard let account = input.fcm.serviceAccount else { throw InputError.emptyServiceAccount }
        let token = try await oauth.accessToken(for: account)
        return try await perform(input: input, account: account, target: target, number: number, accessToken: token)
    }

    /// Builds `{"message": {...}, "validate_only": ...}` with the target inserted into the user's message object.
    static func requestBody(for fcm: FCMInput, target: String) throws -> Data {
        guard let object = try? JSONSerialization.jsonObject(with: Data(fcm.message.utf8)),
              var message = object as? [String: Any] else {
            throw FCMError.invalidMessage(InputValidator.jsonProblem(in: fcm.message) ?? "not an object")
        }
        for kind in FCMTargetKind.allCases { message.removeValue(forKey: kind.rawValue) }
        message[fcm.targetKind.rawValue] = target

        var body: [String: Any] = ["message": message]
        if fcm.validateOnly { body["validate_only"] = true }
        return try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    func perform(input: PushInput, account: GoogleServiceAccount, target: String, number: Int, accessToken: String) async throws -> SendHistoryItem {
        let url = account.sendURL
        let bodyData = try Self.requestBody(for: input.fcm, target: target)
        let bodyText = String(data: bodyData, encoding: .utf8) ?? ""

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        let headers: [(String, String)] = [
            ("content-type", "application/json; charset=UTF-8"),
            ("authorization", "Bearer \(accessToken)")
        ]
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }

        let started = Date()
        let requestString = ["POST \(url.path) HTTP/1.1", "Host: \(url.host ?? "")"]
            + headers.map { "\($0.0): \($0.1)" } + ["", bodyText]
        let keyValues = headers.map { SendHistoryItem.KeyValue(key: $0.0, value: $0.1) }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw FCMError.invalidResponse }
            let duration = Int(Date().timeIntervalSince(started) * 1000)
            let responseHeaders = http.allHeaderFields.compactMap { key, value -> SendHistoryItem.KeyValue? in
                guard let key = key as? String else { return nil }
                return SendHistoryItem.KeyValue(key: key, value: "\(value)")
            }.sorted { $0.key < $1.key }
            let body = String(data: data, encoding: .utf8) ?? ""
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let messageName = json?["name"] as? String
            var reason: String?
            var errorMessage: String?
            if let error = json?["error"] as? [String: Any] {
                errorMessage = error["message"] as? String
                reason = error["status"] as? String
                if let details = error["details"] as? [[String: Any]] {
                    for detail in details {
                        if let code = detail["errorCode"] as? String { reason = code }
                    }
                }
            }

            var responseLines = ["HTTP \(http.statusCode)"]
            for (key, value) in http.allHeaderFields { responseLines.append("\(key): \(value)") }
            responseLines.append("")
            responseLines.append(body.isEmpty ? "(empty body)" : body)

            return SendHistoryItem(
                number: number,
                inputId: input.id,
                statusCode: http.statusCode,
                requestUrl: url.absoluteString,
                requestHeaders: keyValues,
                requestMessage: bodyText,
                responseHeaders: responseHeaders,
                responseReasonCode: reason,
                responseData: body.isEmpty ? nil : body,
                deviceToken: target,
                requestString: requestString.joined(separator: "\n"),
                responseString: responseLines.joined(separator: "\n"),
                environment: .production,
                pushType: .alert,
                durationMs: duration,
                localError: nil,
                platform: .fcm,
                fcmMessageName: messageName,
                fcmErrorMessage: errorMessage,
                projectId: account.projectId
            )
        } catch let error as URLError {
            let duration = Int(Date().timeIntervalSince(started) * 1000)
            return SendHistoryItem(
                number: number,
                inputId: input.id,
                statusCode: 0,
                requestUrl: url.absoluteString,
                requestHeaders: keyValues,
                requestMessage: bodyText,
                responseHeaders: [],
                responseReasonCode: nil,
                responseData: nil,
                deviceToken: target,
                requestString: requestString.joined(separator: "\n"),
                responseString: "No response. \(error.localizedDescription) (URLError \(error.code.rawValue))",
                environment: .production,
                pushType: .alert,
                durationMs: duration,
                localError: error.localizedDescription,
                platform: .fcm,
                fcmMessageName: nil,
                fcmErrorMessage: nil,
                projectId: account.projectId
            )
        }
    }
}

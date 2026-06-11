//
//  SMSServices.swift
//  IPificationSDK
//

import Foundation

/// Stable numeric error codes produced by SMS authentication.
public struct SMSErrorCode {
    /// SMS authentication is not configured correctly.
    public static let configurationError = 8001
    /// Another SMS request is already running.
    public static let requestInProgress = 8002
    /// The SMS request failed at the network layer.
    public static let networkError = 8003
    /// The SMS response could not be parsed.
    public static let parseError = 8004
    /// The SMS backend rejected the request as invalid.
    public static let invalidRequest = 8005
    /// The SMS backend rejected the request as unauthorized.
    public static let unauthorized = 8006
    /// The requested SMS resource was not found.
    public static let notFound = 8007
    /// The SMS backend returned a server error.
    public static let serverError = 8008
    /// An unclassified SMS authentication error occurred.
    public static let unknownError = 8009
}

/// Implements SMS authentication initiation and OTP verification.
public class SMSServices {
    /// Indicates whether an SMS network request is currently running.
    private static var isRequestInProgress = false
    /// The serial queue that protects SMS request state.
    private static let queue = DispatchQueue(label: "com.ipification.sms")

    public static func startVerification(phoneNumber: String, scope: String = "openid ip:phone_verify", callback: SMSCallback) {
        guard isConfigured() else {
            DispatchQueue.main.async { callback.onError(error: error(SMSErrorCode.configurationError, "SMS not properly configured. Set SMS_BACKEND_URL and SMS_AUTH_PATH in IPConfiguration.")) }
            return
        }
        guard beginRequest() else {
            DispatchQueue.main.async { callback.onError(error: error(SMSErrorCode.requestInProgress, "An SMS verification request is already in progress.")) }
            return
        }

        let config = IPConfiguration.sharedInstance
        let url = smsBackendUrl() + config.SMS_AUTH_PATH
        let body: [String: Any] = [
            "client_id": config.CLIENT_ID,
            "server_id": config.SMS_SERVER_ID,
            "login_hint": phoneNumber,
            "scope": scope
        ]

        logRequestStart(label: "SMS_AUTH", url: url, body: body)
        performJSONRequest(label: "SMS_AUTH", url: url, body: body) { result in
            switch result {
            case .success(let (data, rawResponse)):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let authReqId = json["auth_req_id"] as? String,
                          let nonce = json["nonce"] as? String else {
                        finishRequest()
                        logParseError(label: "SMS_AUTH", message: "Failed to parse SMS auth response.", rawResponse: rawResponse)
                        DispatchQueue.main.async { callback.onError(error: error(SMSErrorCode.parseError, "Failed to parse SMS auth response.")) }
                        return
                    }
                    let authServerJson = json["auth_server"] as? [String: Any]
                    let authServer = authServerJson.flatMap { authServer -> SMSAuthResponse.AuthServer? in
                        guard let id = authServer["id"] as? String, let url = authServer["url"] as? String else { return nil }
                        return SMSAuthResponse.AuthServer(id: id, url: url)
                    }
                    DispatchQueue.main.async { callback.onAuthInitiated(response: SMSAuthResponse(authReqId: authReqId, nonce: nonce, authServer: authServer, rawResponse: rawResponse)) }
                } catch {
                    finishRequest()
                    logParseError(label: "SMS_AUTH", message: "Failed to parse SMS auth response: \(error.localizedDescription)", rawResponse: rawResponse)
                    DispatchQueue.main.async { callback.onError(error: Self.error(SMSErrorCode.parseError, "Failed to parse SMS auth response: \(error.localizedDescription)")) }
                }
            case .failure(let error):
                finishRequest()
                DispatchQueue.main.async { callback.onError(error: error) }
            }
        }
    }

    public static func verifyOTP(otpCode: String, authReqId: String, nonce: String, callback: SMSCallback) {
        guard isConfigured() else {
            DispatchQueue.main.async { callback.onError(error: error(SMSErrorCode.configurationError, "SMS not properly configured.")) }
            return
        }

        let config = IPConfiguration.sharedInstance
        let url = smsBackendUrl() + config.SMS_TOKEN_PATH
        let body: [String: Any] = [
            "code": otpCode,
            "auth_req_id": authReqId,
            "client_id": config.CLIENT_ID,
            "nonce": nonce,
            "server_id": config.SMS_SERVER_ID
        ]

        logRequestStart(label: "SMS_TOKEN", url: url, body: body)
        performJSONRequest(label: "SMS_TOKEN", url: url, body: body) { result in
            finishRequest()
            switch result {
            case .success(let (data, rawResponse)):
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let response = SMSTokenResponse(
                        sub: json?["sub"] as? String,
                        phoneNumber: json?["phone_number"] as? String,
                        phoneNumberVerified: json?["phone_number_verified"] as? Bool ?? false,
                        loginHint: json?["login_hint"] as? String,
                        rawResponse: rawResponse
                    )
                    DispatchQueue.main.async { callback.onSuccess(response: response) }
                } catch {
                    logParseError(label: "SMS_TOKEN", message: "Failed to parse SMS token response: \(error.localizedDescription)", rawResponse: rawResponse)
                    DispatchQueue.main.async { callback.onError(error: Self.error(SMSErrorCode.parseError, "Failed to parse SMS token response: \(error.localizedDescription)")) }
                }
            case .failure(let error):
                DispatchQueue.main.async { callback.onError(error: error) }
            }
        }
    }

    public static func reset() {
        finishRequest()
    }

    public static func isConfigured() -> Bool {
        let config = IPConfiguration.sharedInstance
        return smsBackendUrl().isEmpty == false && config.SMS_AUTH_PATH.isEmpty == false && config.SMS_TOKEN_PATH.isEmpty == false && config.CLIENT_ID.isEmpty == false
    }

    private static func beginRequest() -> Bool {
        return queue.sync {
            if isRequestInProgress { return false }
            isRequestInProgress = true
            return true
        }
    }

    private static func finishRequest() {
        queue.sync { isRequestInProgress = false }
    }

    private static func smsBackendUrl() -> String {
        let config = IPConfiguration.sharedInstance
        return config.ENV == .SANDBOX ? config.SMS_BACKEND_URL_SANDBOX : config.SMS_BACKEND_URL_PRODUCTION
    }

    private static func performJSONRequest(label: String, url: String, body: [String: Any], completion: @escaping (Result<(Data, String), IPificationException>) -> Void) {
        guard let endpoint = URL(string: url) else {
            completion(.failure(error(SMSErrorCode.configurationError, "Invalid SMS backend URL.")))
            return
        }
        guard let requestBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(error(SMSErrorCode.invalidRequest, "Invalid SMS request body.")))
            return
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = requestBody
        request.timeoutInterval = IPConfiguration.sharedInstance.AuthReadTimeout / 1000
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                logFailure(label: label, url: url, error: error)
                completion(.failure(Self.error(SMSErrorCode.networkError, "SMS network error: \(error.localizedDescription)", rawResponse: nil)))
                return
            }
            guard let data = data else {
                logResponse(label: label, url: url, response: response, body: "<empty data>")
                completion(.failure(Self.error(SMSErrorCode.networkError, "SMS response data is empty.")))
                return
            }
            let rawResponse = String(data: data, encoding: .utf8) ?? ""
            logResponse(label: label, url: url, response: response, body: rawResponse)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                completion(.failure(parseErrorResponse(httpCode: httpResponse.statusCode, rawResponse: rawResponse)))
                return
            }
            completion(.success((data, rawResponse)))
        }.resume()
    }

    private static func logRequestStart(label: String, url: String, body: [String: Any]) {
        guard IPConfiguration.sharedInstance.debug else { return }
        IPLogs.sharedInstance.append("[SMSServices] \(label) - START")
        IPLogs.sharedInstance.append("[SMSServices] \(label) Request URL: \(url)")
        IPLogs.sharedInstance.append("[SMSServices] \(label) Request Method: POST")
        IPLogs.sharedInstance.append("[SMSServices] \(label) Request Headers: Content-Type=application/json")
        IPLogs.sharedInstance.append("[SMSServices] \(label) Request Body: \(jsonString(body))")
    }

    private static func logResponse(label: String, url: String, response: URLResponse?, body: String) {
        guard IPConfiguration.sharedInstance.debug else { return }
        let httpResponse = response as? HTTPURLResponse
        IPLogs.sharedInstance.append("[SMSServices] \(label) - RESPONSE")
        IPLogs.sharedInstance.append("[SMSServices] \(label) Response URL: \(url)")
        IPLogs.sharedInstance.append("[SMSServices] \(label) Response Status: \(httpResponse?.statusCode ?? -1)")
        if let headers = httpResponse?.allHeaderFields, headers.isEmpty == false {
            IPLogs.sharedInstance.append("[SMSServices] \(label) Response Headers: \(headers)")
        }
        IPLogs.sharedInstance.append("[SMSServices] \(label) Response Body: \(body.isEmpty ? "<empty>" : body)")
    }

    private static func logFailure(label: String, url: String, error: Error) {
        guard IPConfiguration.sharedInstance.debug else { return }
        IPLogs.sharedInstance.append("[SMSServices] \(label) - FAILED")
        IPLogs.sharedInstance.append("[SMSServices] \(label) Failed URL: \(url)")
        IPLogs.sharedInstance.append("[SMSServices] \(label) Error: \(error.localizedDescription)")
    }

    private static func logParseError(label: String, message: String, rawResponse: String) {
        guard IPConfiguration.sharedInstance.debug else { return }
        IPLogs.sharedInstance.append("[SMSServices] \(label) - PARSE_ERROR")
        IPLogs.sharedInstance.append("[SMSServices] \(label) Parse Error: \(message)")
        IPLogs.sharedInstance.append("[SMSServices] \(label) Raw Response: \(rawResponse.isEmpty ? "<empty>" : rawResponse)")
    }

    private static func jsonString(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let string = String(data: data, encoding: .utf8) else {
            return "\(object)"
        }
        return string
    }

    private static func parseErrorResponse(httpCode: Int, rawResponse: String) -> IPificationException {
        let message: String
        let apiErrorCode: String?
        if let data = rawResponse.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let nestedData = json["data"] as? [String: Any] {
                apiErrorCode = nestedData["error"] as? String ?? json["error"] as? String
                message = nestedData["error_description"] as? String
                    ?? nestedData["error"] as? String
                    ?? json["error_description"] as? String
                    ?? json["error"] as? String
                    ?? "HTTP \(httpCode)"
            } else {
                apiErrorCode = json["error"] as? String
                message = json["error_description"] as? String ?? json["error"] as? String ?? "HTTP \(httpCode)"
            }
        } else {
            apiErrorCode = nil
            message = rawResponse.isEmpty ? "HTTP \(httpCode)" : rawResponse
        }
        let code: Int
        switch httpCode {
        case 400: code = SMSErrorCode.invalidRequest
        case 401: code = SMSErrorCode.unauthorized
        case 404: code = SMSErrorCode.notFound
        case 500, 502, 503, 504: code = SMSErrorCode.serverError
        default: code = SMSErrorCode.unknownError
        }
        return IPificationException(.authorized_failed, message, errorCode: apiErrorCode ?? "\(code)", errorDescription: message, rawResponse: rawResponse)
    }

    private static func error(_ code: Int, _ message: String, rawResponse: String? = nil) -> IPificationException {
        return IPificationException(.authorized_failed, message, errorCode: "\(code)", errorDescription: message, rawResponse: rawResponse)
    }
}

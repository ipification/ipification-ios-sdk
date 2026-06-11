//
//  SMSAuthResponse.swift
//  IPificationSDK
//

import Foundation

/// Describes an SMS authentication request that is ready for OTP verification.
public class SMSAuthResponse {
    /// The request identifier required when verifying the OTP.
    public let authReqId: String
    /// The nonce that binds OTP verification to this authentication request.
    public let nonce: String
    /// The authentication server selected for the request, when supplied by the backend.
    public let authServer: AuthServer?
    /// The unmodified response body returned by the SMS backend.
    public let rawResponse: String

    public init(authReqId: String, nonce: String, authServer: AuthServer? = nil, rawResponse: String = "") {
        self.authReqId = authReqId
        self.nonce = nonce
        self.authServer = authServer
        self.rawResponse = rawResponse
    }

    /// Identifies the authentication server that should process OTP verification.
    public class AuthServer {
        /// The server identifier returned by the backend.
        public let id: String
        /// The server base URL returned by the backend.
        public let url: String

        public init(id: String, url: String) {
            self.id = id
            self.url = url
        }
    }
}
